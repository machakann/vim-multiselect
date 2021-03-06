" multiselect.vim : A library for multiple selection
let s:Errors = multiselect#Errors#_import()
let s:Buffer = multiselect#Buffer#_import()
let s:Highlights = multiselect#Highlights#_import()
let s:Schedule = vital#multiselect#new().import('Schedule').augroup('multiselect')
let s:TRUE = 1
let s:FALSE = 0
let s:NULLPOS = [0, 0, 0, 0]

" Multiselector object "{{{
unlockvar! s:Multiselector
let s:Multiselector = {
	\	'name': '',
	\	'bufnr': -1,
	\	'itemlist': [],
	\	'higroup': '',
	\	'EVENTCHECKPOST': '',
	\	'EVENTUNCHECKPOST': '',
	\	'_event': {},
	\	'_last':{
	\		'event': '',
	\		'itemlist': [],
	\		},
	\	'_pending': {
	\		'bufnr': -1,
	\		'_last': {},
	\		'itemlist': [],
	\		},
	\	}
function! s:Multiselector(...) abort "{{{
	let options = get(a:000, 0, {})
	let multiselector = deepcopy(s:Multiselector)
	let multiselector.higroup = get(options, 'higroup', s:Highlights.DEFAULTHIGROUP)
	let multiselector.name = get(options, 'name', '')

	let EVENTCHECKPOST = get(options, 'eventcheckpost', '')
	let EVENTUNCHECKPOST = get(options, 'eventuncheckpost', '')
	let multiselector.EVENTCHECKPOST = EVENTCHECKPOST
	let multiselector.EVENTUNCHECKPOST = EVENTUNCHECKPOST
	call multiselector.event('BufLeave').call(multiselector._initialize, [], multiselector)
	call multiselector.event('TabLeave').call(multiselector._initialize, [], multiselector)
	call multiselector.event('CmdwinEnter').call(multiselector._suspend, [], multiselector)
	call multiselector.event('CmdwinLeave').call(multiselector._initialize, [], multiselector)
	call multiselector.event('CmdwinLeave').call(multiselector._resume, [], multiselector)
	call multiselector.event('TextChanged').call(multiselector.uncheckall, [], multiselector)
	call multiselector.event('InsertEnter').call(multiselector.uncheckall, [], multiselector)
	call multiselector.event('WinNew').call(multiselector._show, [], multiselector)

	call multiselector._initialize()
	return multiselector
endfunction "}}}



" main interfaces
function! s:Multiselector.check(expr, ...) abort  "{{{
	let args = [a:expr] + a:000
	try
		let newitem = call(s:Buffer.Item, args)
	catch /^Vim(echoerr):multiselect: Invalid argument: /
		echoerr s:Errors.InvalidArgument('Multiselector.check', args)
	endtry
	call self.append(newitem)
	return newitem
endfunction "}}}

function! s:Multiselector.checkpattern(pat, ...) abort "{{{
	if empty(a:pat)
		return []
	endif

	if a:0 == 0
		let start = [0, 1, 1, 0]
		let end = [0, line('$'), col([line('$'), '$']), 0]
		let region = s:Buffer.Region(start, end)
	else
		let region = a:1
	endif
	let itemlist = []
	let view = winsaveview()
	call setpos('.', region.head)
	let head = s:Buffer.searchpos(a:pat, 'cW')
	while head != s:NULLPOS && region.includes(head)
		let tail = s:Buffer.searchpos(a:pat, 'ceW')
		if !region.includes(tail)
			break
		endif
		let newitem = s:Buffer.Item(head, tail, 'v')
		call add(itemlist, newitem)
		let head = s:Buffer.searchpos(a:pat, 'W')
	endwhile

	" It is sure that the items in 'itemlist' has no overlap
	call self.unsafe_append(itemlist)
	call winrestview(view)
	return itemlist
endfunction "}}}

function! s:Multiselector.uncheck(expr, ...) abort  "{{{
	let args = [a:expr] + a:000
	try
		let unchecked = call(self.emit_touching, args, self)
	catch /^Vim(echoerr):multiselect: Invalid argument: /
		echoerr s:Errors.InvalidArgument('Multiselector.uncheck', args)
	endtry
	return unchecked
endfunction "}}}

function! s:Multiselector.uncheckall() abort  "{{{
	return self.remove(0, -1)
endfunction "}}}

function! s:Multiselector.emit(...) abort "{{{
	if a:0 == 0
		return self.remove(0, -1)
	endif
	let Filterexpr = a:1
	let filtered = s:percolate(self.itemlist, Filterexpr)
	if filtered != []
		call self._uncheckpost(filtered)
	endif
	return filtered
endfunction "}}}

function! s:Multiselector.emit_inside(expr, ...) abort "{{{
	let args = [a:expr] + a:000
	try
		let itemlist = self.emit({_, item -> call(item.isinside, args, item)})
	catch /^Vim(echoerr):multiselect: Invalid argument: /
		echoerr s:Errors.InvalidArgument('Multiselector.emit_inside', args)
	endtry
	return itemlist
endfunction "}}}

function! s:Multiselector.emit_touching(expr, ...) abort "{{{
	let args = [a:expr] + a:000
	try
		let itemlist = self.emit({_, item -> call(item.touches, args, item)})
	catch /^Vim(echoerr):multiselect: Invalid argument: /
		echoerr s:Errors.InvalidArgument('Multiselector.emit_touching', args)
	endtry
	return itemlist
endfunction "}}}

function! s:Multiselector.filter(Filterexpr) abort "{{{
	call self.emit({i1, i2 -> !a:Filterexpr(i1, i2)})
	return self.itemlist
endfunction
"}}}

function! s:Multiselector.sort(itemlist) abort "{{{
	if empty(a:itemlist)
		return a:itemlist
	endif
	let item = a:itemlist[0]
	if type(item) is v:t_list && len(item) == 2 &&
			\ type(item[0]) is v:t_number && type(item[1]) is v:t_dict
		return sort(a:itemlist, 's:sort_enumerated_items')
	elseif type(item) is v:t_dict
		return sort(a:itemlist, 's:sort_items')
	endif
	echoerr s:Errors.InvalidArgument('Multiselect.sort', [a:itemlist])
endfunction "}}}

function! s:sort_items(i1, i2) abort "{{{
	if a:i1.head == a:i2.head
		return 0
	endif
	if a:i1.type is# 'block' && a:i2.type is# 'char'
		if a:i1.head[1] <= a:i2.head[1] && a:i2.tail[1] <= a:i1.tail[1]
			return virtcol(a:i1.head[1:2]) - virtcol(a:i2.head[1:2])
		endif
	elseif a:i1.type is# 'char' && a:i2.type is# 'block'
		if a:i2.head[1] <= a:i1.head[1] && a:i1.tail[1] <= a:i2.tail[1]
			return virtcol(a:i1.head[1:2]) - virtcol(a:i2.head[1:2])
		endif
	elseif a:i1.type is# 'block' && a:i2.type is# 'block'
		if (a:i1.head[1] <= a:i2.head[1] && a:i2.head[1] <= a:i1.tail[1]) ||
			\ (a:i2.head[1] <= a:i1.head[1] && a:i1.head[1] <= a:i2.tail[1])
			return virtcol(a:i1.head[1:2]) - virtcol(a:i2.head[1:2])
		endif
	endif
	return s:Buffer.inorderof(a:i1.head, a:i2.head) ? -1 : 1
endfunction "}}}

function! s:sort_enumerated_items(i1, i2) abort "{{{
	return s:sort_items(a:i1[1], a:i2[1])
endfunction "}}}



" keymap interfaces
function! s:Multiselector.keymap_check(mode) abort "{{{
	if a:mode is# 'n'
		if foldclosed(line('.')) != -1
			normal! zO
		endif
		normal! viw
		execute "normal! \<Esc>"
	endif
	let head = getpos("'<")
	let tail = getpos("'>")
	let type = visualmode()
	if a:mode is# 'x' && type is# "\<C-v>"
		let extended = s:Buffer.isextended()
	else
		let extended = s:FALSE
	endif
	let newitem = self.check(head, tail, type, extended)
	let view = winsaveview()
	call winrestview(view)
	return newitem
endfunction "}}}

function! s:Multiselector.keymap_checkpattern(mode, pat, ...) abort "{{{
	if a:mode is# 'x'
		let region = s:Buffer.Region(getpos("'<"), getpos("'>"))
		let itemlist = self.checkpattern(a:pat, region)
	else
		let itemlist = self.checkpattern(a:pat)
	endif

	let options = get(a:000, 0, {})
	if get(options, 'openfold', s:FALSE) is s:TRUE
		let view = winsaveview()
		for item in itemlist
			call setpos('.', item.head)
			call s:Buffer.openfold()
		endfor
		call winrestview(view)
	endif
	return itemlist
endfunction "}}}

function! s:Multiselector.keymap_uncheck(mode) abort "{{{
	if a:mode is# 'x'
		return self.uncheck(getpos("'<"), getpos("'>"))
	endif
	return self.uncheck(getpos('.'))
endfunction "}}}

function! s:Multiselector.keymap_uncheckall() abort "{{{
	return self.uncheckall()
endfunction "}}}

function! s:Multiselector.keymap_undo() abort "{{{
	let last = self.lastevent()
	if last.event is# 'check'
		for checked in last.itemlist
			call self.filter({_, item -> item isnot checked})
		endfor
	elseif last.event is# 'uncheck'
		call self.append(last.itemlist)
	endif
endfunction "}}}

function! s:Multiselector.keymap_next(mode) abort "{{{
	let l:count = v:count1
	let curpos = getpos('.')
	let itemlist = self.enumerate(
		\	{_, item -> s:Buffer.inorderof(curpos, item.head)})
	if empty(itemlist)
		return copy(s:NULLPOS)
	endif
	call map(itemlist, 'v:val[1]')
	call self.sort(itemlist)
	let idx = min([l:count - 1, len(itemlist) - 1])
	let dest = itemlist[idx]
	call setpos('.', dest.head)
	return dest.head
endfunction "}}}

function! s:Multiselector.keymap_previous(mode) abort "{{{
	let l:count = v:count1
	let curpos = getpos('.')
	let itemlist = self.enumerate(
		\	{_, item -> s:Buffer.inorderof(item.head, curpos)})
	if empty(itemlist)
		return copy(s:NULLPOS)
	endif
	call map(itemlist, 'v:val[1]')
	call self.sort(itemlist)
	let idx = max([-l:count, -len(itemlist)])
	let dest = itemlist[idx]
	call setpos('.', dest.head)
	return dest.head
endfunction "}}}

function! s:Multiselector.keymap_multiselect(mode) abort "{{{
	let itemlist = []
	if a:mode is# 'x'
		let type = s:Buffer.str2type(visualmode())
		let extended = s:Buffer.isextended()
		let region = s:Buffer.Region(getpos("'<"), getpos("'>"), type, extended)
		if type is# 'char'
			if self.itemnum({_, item -> region.includes(item)}) != 0
				call self.filter({_, item -> region.includes(item)})
			elseif self.itemnum({_, item -> region.isinside(item)}) != 0
				let pat = s:Buffer.patternofselection(region)
				let item = self.emit({_, item -> region.isinside(item)})[0]
				call self.checkpattern(pat, item)
			else
				call self.keymap_check(a:mode)
			endif
		else
			if self.itemnum({_, item -> region.includes(item)}) != 0
				call self.filter({_, item -> region.includes(item)})
			else
				call self.keymap_check(a:mode)
			endif
		endif
	else
		let curpos = getpos('.')
		let pat = printf('\<%s\>', expand('<cword>'))
		if self.itemnum({_, item -> item.touches(curpos)}) != 0
			let item = self.emit_touching(curpos)[0]
			call self.checkpattern(pat, item)
		else
			call self.checkpattern(pat)
		endif
	endif
endfunction "}}}

function! s:Multiselector.keymap_broadcast(cmd, ...) abort "{{{
	let options = get(a:000, 0, {})
	let remap = !!get(options, 'remap', s:FALSE)
	let openfold = !!get(options, 'openfold', s:FALSE)
	let countstr = s:countstr(v:prevcount)
	let visualcmd = visualmode()
	if visualcmd !=# 'V'
		let flag = remap ? 'im' : 'in'
		call feedkeys(printf('gv%s%s', countstr, a:cmd), flag)
		return
	endif

	let view = winsaveview()
	let vhead = getpos("'<")
	let vtail = getpos("'>")
	let startlnum = vhead[1]
	let endlnum = vtail[1]
	let column = virtcol('.')
	let command = s:selector_buildcommand(remap, countstr, a:cmd)
	let itemlist = []
	for lnum in range(startlnum, endlnum)
		let item = s:try(lnum, column, command)
		if !empty(item)
			if openfold
				call s:Buffer.openfold(lnum)
			endif
			call add(itemlist, item)
		endif
	endfor
	call self.append(itemlist)

	normal! V
	execute "normal! \<Esc>"
	call setpos("'<", vhead)
	call setpos("'>", vtail)
	call winrestview(view)
endfunction "}}}

function! s:selector_buildcommand(remap, countstr, cmd) abort "{{{
	if a:remap is s:TRUE
		let bang = ''
	else
		let bang = '!'
	endif
	return printf('noautocmd normal%s v%s%s', bang, a:countstr, a:cmd)
endfunction "}}}

function! s:try(lnum, column, command) abort "{{{
	let line = getline(a:lnum)
	if empty(line) || strdisplaywidth(line) < a:column
		return {}
	endif

	execute printf('normal! %dG%d|', a:lnum, a:column)
	let curpos = getpos('.')
	execute a:command
	if mode() isnot# 'v'
		return {}
	endif
	execute "normal! \<Esc>"
	let vhead = getpos("'<")
	let vtail = getpos("'>")
	if vhead[1] != curpos[1] || vtail[1] != curpos[1] ||
			\ (vhead[2] == curpos[2] && vtail[2] == curpos[2])
		return {}
	endif
	if virtcol(vtail[1:2]) <= indent(vtail[1])
		return {}
	endif
	return s:Multiselect.Item(vhead, vtail, 'char')
endfunction "}}}

function! s:countstr(count) abort "{{{
	return a:count ? string(a:count) : ''
endfunction "}}}



" low-level interfaces
function! s:Multiselector.append(item) abort "{{{
	if empty(a:item)
		return self.itemlist
	endif

	if self.bufnr == -1
		let self.bufnr = bufnr('%')
	endif

	let t_item = type(a:item)
	if t_item is v:t_dict
		let itemlist = [a:item]
	elseif t_item is v:t_list
		let itemlist = a:item
	else
		call s:Errors.InvalidArgument('Multiselector.append', [a:item])
	endif

	let added = []
	for newitem in itemlist
		if empty(newitem) || newitem.bufnr != self.bufnr
			continue
		endif
		call self.filter({_, olditem -> !newitem.touches(olditem)})
		call add(self.itemlist, newitem)
		call add(added, newitem)
	endfor
	call self._checkpost(added)
	return self.itemlist
endfunction "}}}

function! s:Multiselector.remove(...) abort "{{{
	if self.itemnum() == 0
		return []
	endif

	let removed = []
	if a:0 == 1
		let type_arg = type(a:1)
		if type_arg is v:t_number
			let removed = remove(self.itemlist, a:1)
			call self._uncheckpost([removed])
			return removed
		elseif type_arg is v:t_list
			for i in reverse(sort(copy(a:1), 'n'))
				call add(removed, remove(self.itemlist, i))
			endfor
			call reverse(removed)
		endif
	elseif a:0 >= 2
		let removed = remove(self.itemlist, a:1, a:2)
	endif
	if !empty(removed)
		call self._uncheckpost(removed)
	endif
	return removed
endfunction "}}}

function! s:Multiselector.enumerate(...) abort "{{{
	let itemlist = s:enumerate(self.itemlist)
	if a:0 == 0
		return itemlist
	endif
	return filter(itemlist, {index, list -> call(a:1, [index, list[1]])})
endfunction "}}}

function! s:Multiselector.search(searched) abort "{{{
	let i = 0
	for item in self.itemlist
		if item is# a:searched
			return i
		endif
		let i += 1
	endfor
	return -1
endfunction "}}}

function! s:Multiselector.itemnum(...) abort "{{{
	if a:0 == 0
		return len(self.itemlist)
	endif
	let Filterexpr = a:1
	return len(filter(copy(self.itemlist), Filterexpr))
endfunction "}}}

function! s:Multiselector.isempty() abort "{{{
	return empty(self.itemlist)
endfunction "}}}

function! s:Multiselector.lastevent() abort "{{{
	let last = copy(self._last)
	let last.itemlist = copy(self._last.itemlist)
	return last
endfunction "}}}

function! s:Multiselector.show(...) abort "{{{
	if a:0 == 0
		let itemlist = self.itemlist
	else
		let Filterexpr = a:1
		let itemlist = self.list(Filterexpr)
	endif
	for item in itemlist
		call item.show(self.higroup)
	endfor
endfunction "}}}

function! s:Multiselector.quench(...) abort "{{{
	if a:0 == 0
		let itemlist = self.itemlist
	else
		let Filterexpr = a:1
		let itemlist = self.list(Filterexpr)
	endif
	for item in self.itemlist
		call item.quench()
	endfor
endfunction "}}}

function! s:Multiselector.unsafe_append(item) abort "{{{
	if empty(a:item)
		return self.itemlist
	endif

	if self.bufnr == -1
		let self.bufnr = bufnr('%')
	endif

	let t_item = type(a:item)
	if t_item is v:t_dict
		let itemlist = [a:item]
	elseif t_item is v:t_list
		let itemlist = a:item
	else
		call s:Errors.InvalidArgument('Multiselector.unsafe_append', [a:item])
	endif

	if empty(itemlist)
		return self.itemlist
	endif

	for newitem in itemlist
		if empty(newitem) || newitem.bufnr != self.bufnr
			continue
		endif
		call self.filter({_, olditem -> !newitem.touches(olditem)})
	endfor
	call extend(self.itemlist, itemlist)
	call self._checkpost(itemlist)
	return self.itemlist
endfunction "}}}

function! s:percolate(iter, Filterexpr) abort "{{{
	let percolated = filter(copy(a:iter), {i1, i2 -> a:Filterexpr(i1, i2)})
	call filter(a:iter, {i1, i2 -> !a:Filterexpr(i1, i2)})
	return percolated
endfunction "}}}

function! s:enumerate(list, ...) abort "{{{
	let start = get(a:000, 0, 0)
	return map(copy(a:list), {i, item -> [start + i, item]})
endfunction "}}}



" event control
function! s:Multiselector.event(name) abort "{{{
	if !has_key(self._event, a:name)
		let self._event[a:name] = s:Schedule.Task().repeat(-1)
		call self._event[a:name].waitfor([a:name])
	endif
	return self._event[a:name]
endfunction "}}}



" private methods
function! s:Multiselector._initialize() abort "{{{
	let self.bufnr = -1
	call self.uncheckall()
endfunction "}}}

function! s:Multiselector._suspend() abort "{{{
	let self._pending.bufnr = self.bufnr
	let self._pending.itemlist = self.itemlist
	let self._pending._last = self._last
	let self.bufnr = -1
	let self.itemlist = []
	let self._last = {}
	let self._last.event = ''
	let self._last.itemlist = []
endfunction "}}}

function! s:Multiselector._resume() abort "{{{
	let self.bufnr = self._pending.bufnr
	let self.itemlist = self._pending.itemlist
	let self._last = self._pending._last
	let self._pending.bufnr = -1
	let self._pending.itemlist = []
	let self._pending._last = {}
	let self._pending._last.event = ''
	let self._pending._last.itemlist = []
endfunction "}}}

function! s:Multiselector._show() abort "{{{
	let winid = win_getid()
	for item in self.itemlist
		if item.isshownin(winid)
			call item._showlocal(self.higroup)
		endif
	endfor
endfunction "}}}

function! s:Multiselector._checkpost(added) abort "{{{
	if empty(a:added)
		return
	endif
	for item in a:added
		call item.show(self.higroup)
	endfor
	let self._last.event = 'check'
	let self._last.itemlist = a:added
	call s:douserautocmd(self.EVENTCHECKPOST)
endfunction "}}}

function! s:Multiselector._uncheckpost(removed) abort "{{{
	if empty(a:removed)
		return
	endif
	for item in a:removed
		call item.quench()
	endfor
	let self._last.event = 'uncheck'
	let self._last.itemlist = a:removed
	call s:douserautocmd(self.EVENTUNCHECKPOST)
endfunction "}}}

function! s:Multiselector._abandon() abort "{{{
	call self.uncheckall()
	for event in values(self._event)
		call event.cancel()
	endfor
endfunction "}}}
lockvar! s:Multiselector
"}}}



function! s:shiftenv() abort "{{{
	let env = {}
	if !empty(&l:indentexpr)
		let env.indentkeys = &l:indentkeys
		setlocal indentkeys&
	elseif &l:cindent is s:TRUE
		let env.cinkeys = &l:cinkeys
		setlocal cinkeys&
	endif
	return env
endfunction "}}}

function! s:restoreenv(env) abort "{{{
	if empty(a:env)
		return
	endif

	if has_key(a:env, 'indentkeys')
		let &l:indentkeys = a:env.indentkeys
	elseif has_key(a:env, 'cinkeys')
		let &l:cinkeys = a:env.cinkeys
	endif
endfunction "}}}

function! s:douserautocmd(name) abort "{{{
	if !exists('#User#' . a:name)
		return
	endif
	execute 'doautocmd <nomodeline> User ' . a:name
endfunction "}}}



" Multiselect module{{{
function! s:load() abort "{{{
	return s:multiselector
endfunction "}}}

unlockvar! s:Multiselect
let s:Multiselect = {
	\	'__MODULE__': 'Multiselect',
	\	'DEFAULTHIGROUP': s:Highlights.DEFAULTHIGROUP,
	\	'load': function('s:load'),
	\	'Multiselector': function('s:Multiselector'),
	\	'Region': s:Buffer.Region,
	\	'Item': s:Buffer.Item,
	\	'Change': s:Buffer.Change,
	\	'MetaTask': s:Schedule.MetaTask,
	\	'NeatTask': s:Schedule.NeatTask,
	\	'Task': s:Schedule.Task,
	\	'TaskChain': s:Schedule.TaskChain,
	\	'shiftenv': function('s:shiftenv'),
	\	'restoreenv': function('s:restoreenv'),
	\	'percolate': function('s:percolate'),
	\	'enumerate': function('s:enumerate'),
	\	'str2type': s:Buffer.str2type,
	\	'str2visualcmd': s:Buffer.str2visualcmd,
	\	'inorderof': s:Buffer.inorderof,
	\	'inbetween': s:Buffer.inbetween,
	\	'isextended': s:Buffer.isextended,
	\	}
lockvar! s:Multiselect
"}}}

function! multiselect#import() abort "{{{
	return s:Multiselect
endfunction "}}}

let s:multiselector = s:Multiselect.Multiselector({
	\	'name': 'multiselect',
	\	'higroup': s:Highlights.DEFAULTHIGROUP,
	\	'eventcheckpost': 'MultiselectCheckPost',
	\	'eventuncheckpost': 'MultiselectUncheckPost',
	\	})
call s:douserautocmd('MultiselectEnter')
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
