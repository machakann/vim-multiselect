" multiselect.vim : A library for multiple selection
let s:Errors = multiselect#Errors#_import()
let s:Buffer = multiselect#Buffer#_impor()
let s:Highlights = multiselect#Highlights#_import()
let s:Events = multiselect#Events#_import()
let s:TRUE = 1
let s:FALSE = 0
let s:MAXCOL = 2147483647
let s:NULLPOS = [0, 0, 0, 0]

function! multiselect#import() abort "{{{
	return s:Multiselect
endfunction "}}}

let s:table = []
function! multiselect#_gettable() abort "{{{
	return s:table
endfunction "}}}

" Multiselector class "{{{
unlockvar! s:Multiselector
let s:Multiselector = {
	\	'__CLASS__': 'Multiselector',
	\	'name': '',
	\	'bufnr': -1,
	\	'itemlist': [],
	\	'higroup': '',
	\	'event': {
	\		'BufLeave': s:Events.Event('BufLeave'),
	\		'TabLeave': s:Events.Event('TabLeave'),
	\		'CmdwinEnter': s:Events.Event('CmdwinEnter'),
	\		'CmdwinLeave': s:Events.Event('CmdwinLeave'),
	\		'TextChanged': s:Events.Event('TextChanged'),
	\		'InsertEnter': s:Events.Event('InsertEnter'),
	\		'WinNew': s:Events.Event('WinNew'),
	\		'Init': {},
	\		'CheckPost': {},
	\		'UncheckPost': {},
	\		},
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

	let EVENTINIT = get(options, 'eventinit', '')
	let EVENTCHECKPOST = get(options, 'eventcheckpost', '')
	let EVENTUNCHECKPOST = get(options, 'eventuncheckpost', '')
	let multiselector.event.Init = s:Events.Event(EVENTINIT)
	let multiselector.event.CheckPost = s:Events.Event(EVENTCHECKPOST)
	let multiselector.event.UncheckPost = s:Events.Event(EVENTUNCHECKPOST)

	let l:Initializefunc = function(multiselector._initialize, [], multiselector)
	let l:Suspendfunc = function(multiselector._suspend, [], multiselector)
	let l:Resumefunc = function(multiselector._resume, [], multiselector)
	let l:Uncheckallfunc = function(multiselector._uncheckall, [], multiselector)
	let l:Showfunc = function(multiselector._show, [], multiselector)
	call multiselector.event.BufLeave.set(l:Initializefunc)
	call multiselector.event.TabLeave.set(l:Initializefunc)
	call multiselector.event.CmdwinEnter.set(l:Suspendfunc)
	call multiselector.event.CmdwinLeave.set(l:Initializefunc)
	call multiselector.event.CmdwinLeave.set(l:Resumefunc)
	call multiselector.event.TextChanged.set(l:Uncheckallfunc)
	call multiselector.event.InsertEnter.set(l:Uncheckallfunc)
	call multiselector.event.WinNew.set(l:Showfunc)
	call multiselector.event.Init.set(function('s:douserautocmd'))
	call multiselector.event.CheckPost.set(function('s:douserautocmd'))
	call multiselector.event.UncheckPost.set(function('s:douserautocmd'))
	for event in values(multiselector.event)
		if !empty(event.name)
			call event.on()
		endif
	endfor

	call add(s:table, multiselector)
	call multiselector._initialize()
	return multiselector
endfunction "}}}
function! s:douserautocmd(name) abort "{{{
	if !exists('#User#' . a:name)
		return
	endif
	execute 'doautocmd <nomodeline> User ' . a:name
endfunction "}}}

" main interfaces
function! s:Multiselector.check(expr, ...) abort  "{{{
	try
		let newitem = call(s:Buffer.Item, [a:expr] + a:000)
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:Errors.InvalidArgument('Multiselector.check')
	endtry
	call self.add(newitem)
	return newitem
endfunction "}}}
function! s:Multiselector.uncheck(expr, ...) abort  "{{{
	try
		let unchecked = call(self.emit_touching, [a:expr] + a:000, self)
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:Errors.InvalidArgument('Multiselector.uncheck')
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
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:Errors.InvalidArgument('Multiselector.emit_inside')
	endtry
	return itemlist
endfunction "}}}
function! s:Multiselector.emit_touching(expr, ...) abort "{{{
	let args = [a:expr] + a:000
	try
		let itemlist = self.emit({_, item -> call(item.touches, args, item)})
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:Errors.InvalidArgument('Multiselector.emit_touching')
	endtry
	return itemlist
endfunction "}}}
function! s:Multiselector.filter(Filterexpr) abort "{{{
	call self.emit({i1, i2 -> !a:Filterexpr(i1, i2)})
	return self.itemlist
endfunction
"}}}
function! s:Multiselector.sort(itemlist) abort "{{{
	return sort(a:itemlist, 's:sort_items')
endfunction "}}}
function! s:sort_items(i1, i2) abort "{{{
	if a:i1.head == a:i2.head
		return 0
	endif
	if a:i1.type ==# 'block' && a:i2.type ==# 'char'
		if a:i1.head[1] <= a:i2.head[1] && a:i2.tail[1] <= a:i1.tail[1]
			return virtcol(a:i1.head[1:2]) - virtcol(a:i2.head[1:2])
		endif
	elseif a:i1.type ==# 'char' && a:i2.type ==# 'block'
		if a:i2.head[1] <= a:i1.head[1] && a:i1.tail[1] <= a:i2.tail[1]
			return virtcol(a:i1.head[1:2]) - virtcol(a:i2.head[1:2])
		endif
	elseif a:i1.type ==# 'block' && a:i2.type ==# 'block'
		if (a:i1.head[1] <= a:i2.head[1] && a:i2.head[1] <= a:i1.tail[1]) ||
			\ (a:i2.head[1] <= a:i1.head[1] && a:i1.head[1] <= a:i2.tail[1])
			return virtcol(a:i1.head[1:2]) - virtcol(a:i2.head[1:2])
		endif
	endif
	return s:Buffer.inorderof(a:i1.head, a:i2.head) ? -1 : 1
endfunction "}}}

" keymap interfaces
function! s:Multiselector.keymap_check(mode) abort "{{{
	if a:mode ==# 'n'
		if foldclosed(line('.')) != -1
			normal! zO
		endif
		normal! viw
		execute "normal! \<Esc>"
	endif
	let head = getpos("'<")
	let tail = getpos("'>")
	let type = visualmode()
	if a:mode ==# 'x' && type ==# "\<C-v>"
		let extended = s:Buffer.is_extended()
	else
		let extended = s:FALSE
	endif
	let newitem = self.check(head, tail, type, extended)
	let view = winsaveview()
	call winrestview(view)
	return newitem
endfunction "}}}
function! s:Multiselector.keymap_checkpattern(mode, pat, ...) abort "{{{
	if empty(a:pat)
		return
	endif

	let options = get(a:000, 0, {})
	let openfold = get(options, 'openfold', s:FALSE)
	let view = winsaveview()
	if a:mode ==# 'x'
		let start = getpos("'<")
		let end = getpos("'>")
	else
		let start = [0, 1, 1, 0]
		let end = [0, line('$'), col([line('$'), '$']), 0]
	endif
	let region = s:Buffer.Region(start, end)
	call setpos('.', region.head)

	let itemlist = []
	let head = s:Buffer.searchpos(a:pat, 'cW')
	while head != s:NULLPOS && region.includes(head)
		let tail = s:Buffer.searchpos(a:pat, 'ceW')
		if !region.includes(tail)
			break
		endif
		let newitem = s:Buffer.Item(head, tail, 'v')
		call add(itemlist, newitem)
		if openfold is s:TRUE
			call s:Buffer.foldopen(newitem.head[1])
		endif
		let head = s:Buffer.searchpos(a:pat, 'W')
	endwhile

	" It is sure that the items in 'itemlist' has no overlap
	if !empty(itemlist)
		for newitem in itemlist
			call self.filter({_, olditem -> !newitem.touches(olditem)})
		endfor
		call extend(self.itemlist, itemlist)
		call self._checkpost(itemlist)
	endif
	call winrestview(view)
	return itemlist
endfunction "}}}
function! s:Multiselector.keymap_uncheck(mode) abort "{{{
	if a:mode ==# 'x'
		return self.uncheck(getpos("'<"), getpos("'>"))
	endif
	return self.uncheck(getpos('.'))
endfunction "}}}
function! s:Multiselector.keymap_uncheckall() abort "{{{
	return self.uncheckall()
endfunction "}}}
function! s:Multiselector.keymap_undo() abort "{{{
	let last = self.lastevent()
	if last.event ==# 'check'
		let removing = []
		for checked in last.itemlist
			let i = self.search(checked)
			if i != -1
				call add(removing, i)
			endif
		endfor
		call self.remove(removing)
	elseif last.event ==# 'uncheck'
		call self.extend(last.itemlist)
	endif
endfunction "}}}
function! s:Multiselector.keymap_multiselect(mode) abort "{{{
	let itemlist = []
	if a:mode ==# 'x'
		let type = s:Buffer.str2type(visualmode())
		let extended = type ==# 'block' ? s:Buffer.is_extended() : s:FALSE
		let region = s:Buffer.Region(getpos("'<"), getpos("'>"), type, extended)
		let item_in_visual = self.itemnum({_, item -> item.isinside(region)})
		if item_in_visual == 0
			if type ==# 'char'
				let pat = s:Buffer.patternofselection(region)
				call self.keymap_checkpattern('n', pat)
			else
				call self.keymap_check(a:mode)
			endif
		else
			if item_in_visual != self.itemnum()
				call self.filter({_, item -> item.isinside(region)})
			endif
		endif
		return
	else
		let curpos = getpos('.')
		let itemlist = self.emit_touching(curpos)
		if empty(itemlist)
			let pat = printf('\<%s\>', expand('<cword>'))
			call self.keymap_checkpattern(a:mode, pat)
		endif
	endif
endfunction "}}}

" low-level interfaces
function! s:Multiselector.extend(itemlist) abort "{{{
	if empty(a:itemlist)
		return self.itemlist
	endif

	if self.bufnr == -1
		let self.bufnr = bufnr('%')
	endif

	let added = []
	for newitem in a:itemlist
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
function! s:Multiselector.add(item) abort "{{{
	return self.extend([a:item])
endfunction "}}}
function! s:Multiselector.remove(...) abort "{{{
	if self.itemnum() == 0
		return []
	endif

	let removed = []
	if a:0 == 1
		let type_arg = type(a:1)
		if type_arg == v:t_number
			let removed = remove(self.itemlist, a:1)
			call self._uncheckpost([removed])
			return removed
		elseif type_arg == v:t_list
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
function! s:percolate(iter, Filterexpr) abort "{{{
	let t_iter = type(a:iter)
	let filtered = []
	if t_iter == v:t_list
		let i = len(a:iter) - 1
		while i >= 0
			if call(a:Filterexpr, [i, a:iter[i]])
				call add(filtered, remove(a:iter, i))
			endif
			let i -= 1
		endwhile
		return filtered
	elseif t_iter == v:t_dict
		for [key, val] in items(a:iter)
			if call(a:Filterexpr, [key, val])
				call add(filtered, remove(a:iter, key))
			endif
		endfor
		return filtered
	endif
	echoerr s:Errors.InvalidArgument('percolate')
endfunction "}}}
function! s:enumerate(list) abort "{{{
	return map(copy(a:list), {i, item -> [i, item]})
endfunction "}}}

" private methods
function! s:Multiselector._initialize(...) abort "{{{
	let self.bufnr = -1
	call self.uncheckall()
	call self.event.Init.trigger()
endfunction "}}}
function! s:Multiselector._suspend(...) abort "{{{
	let self._pending.bufnr = self.bufnr
	let self._pending.itemlist = self.itemlist
	let self._pending._last = self._last
	let self.bufnr = -1
	let self.itemlist = []
	let self._last = {}
	let self._last.event = ''
	let self._last.itemlist = []
endfunction "}}}
function! s:Multiselector._resume(...) abort "{{{
	let self.bufnr = self._pending.bufnr
	let self.itemlist = self._pending.itemlist
	let self._last = self._pending._last
	let self._pending.bufnr = -1
	let self._pending.itemlist = []
	let self._pending._last = {}
	let self._pending._last.event = ''
	let self._pending._last.itemlist = []
endfunction "}}}
function! s:Multiselector._uncheckall(...) abort "{{{
	call self.uncheckall()
endfunction "}}}
function! s:Multiselector._show(...) abort "{{{
	let winid = win_getid()
	for item in self.itemlist
		if item._histatus(winid) is s:Highlights.OFF
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
	call self.event.CheckPost.trigger()
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
	call self.event.UncheckPost.trigger()
endfunction "}}}
lockvar! s:Multiselector
"}}}

" Multiselect module{{{
unlockvar! s:Multiselect
function! s:load() abort "{{{
	return s:multiselector
endfunction "}}}
let s:Multiselect = {
	\	'__MODULE__': 'Multiselect',
	\	'DEFAULTHIGROUP': s:Highlights.DEFAULTHIGROUP,
	\	'load': function('s:load'),
	\	'Multiselector': function('s:Multiselector'),
	\	'Region': s:Buffer.Region,
	\	'Item': s:Buffer.Item,
	\	'percolate': function('s:percolate'),
	\	'enumerate': function('s:enumerate'),
	\	'str2type': s:Buffer.str2type,
	\	'str2visualcmd': s:Buffer.str2visualcmd,
	\	'inorderof': s:Buffer.inorderof,
	\	'inbetween': s:Buffer.inbetween,
	\	}
lockvar! s:Multiselect
"}}}
let s:multiselector = s:Multiselect.Multiselector({
	\	'name': 'multiselect',
	\	'higroup': s:Highlights.DEFAULTHIGROUP,
	\	'eventinit': 'MultiselectInit',
	\	'eventcheckpost': 'MultiselectCheckPost',
	\	'eventuncheckpost': 'MultiselectUncheckPost',
	\	})
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
