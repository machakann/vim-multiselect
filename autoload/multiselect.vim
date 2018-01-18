" multiselect.vim : A library for multiple selection
" TODO: better error messaging
let s:ClassSys = multiselect#ClassSys#_import()
let s:Highlights = multiselect#Highlights#_import()
let s:Events = multiselect#Events#_import()
let s:TRUE = 1
let s:FALSE = 0
let s:MAXCOL = 2147483647
let s:NULLPOS = [0, 0, 0, 0]
let s:HIGROUP = 'MultiselectItem'

let s:table = []

function! multiselect#import() abort "{{{
	return s:Multiselect
endfunction "}}}

" Region class{{{
let s:Region = {
	\	'__CLASS__': 'Region',
	\	'head': copy(s:NULLPOS),
	\	'tail': copy(s:NULLPOS),
	\	'type': 'char',
	\	'extended': s:FALSE,
	\	}
function! s:Region(expr, ...) abort "{{{
	let head = s:NULLPOS
	let tail = s:NULLPOS
	let t_expr = type(a:expr)
	if a:0 == 0
		if t_expr == v:t_number
			let lnum = a:expr
			let head = [0, lnum, 1, 0]
			let tail = [0, lnum, s:MAXCOL, 0]
			let type = 'line'
		elseif t_expr == v:t_list
			let pos = a:expr
			let head = copy(pos)
			let tail = copy(pos)
			let type = 'char'
		else
			echoerr s:err_InvalidArgument('Region')
		endif
	else
		if t_expr == v:t_number && type(a:1) == v:t_number
			let lnum1 = a:expr
			let lnum2 = a:1
			let head = [0, lnum1, 1, 0]
			let tail = [0, lnum2, s:MAXCOL, 0]
			let type = 'line'
		elseif t_expr == v:t_list && type(a:1) == v:t_list
			let pos1 = a:expr
			let pos2 = a:1
			let type = s:str2type(get(a:000, 1, 'char'))
			if type ==# 'line'
				let head = [0, pos1[1], 1, 0]
				let tail = [0, pos2[1], s:MAXCOL, 0]
			else
				let head = copy(pos1)
				let tail = copy(pos2)
			endif
		else
			echoerr s:err_InvalidArgument('Region')
		endif
	endif
	if head == s:NULLPOS || tail == s:NULLPOS || s:inorderof(tail, head)
		echoerr s:err_InvalidArgument('Region')
	endif

	let region = deepcopy(s:Region)
	let region.head = head
	let region.tail = tail
	let region.type = type
	if region.type ==# 'block'
		let region.extended = !!get(a:000, 2, s:FALSE)
	endif
	return region
endfunction "}}}
function! s:Region.select() abort "{{{
	let visualcmd = s:str2visualcmd(self.type)
	execute 'normal! ' . visualcmd
	call setpos('.', self.head)
	normal! o
	call setpos('.', self.tail)
	if self.extended
		normal! $
	endif
endfunction "}}}
function! s:Region.yank() abort "{{{
	" FIXME: Should I restore visualmode() ?
	let reg = ['"', getreg('"'), getregtype('"')]
	let modhead = getpos("'<")
	let modtail = getpos("'>")
	try
		call self.select()
		normal! ""y
		let text = @@
	finally
		call setpos("'<", modhead)
		call setpos("'>", modtail)
		call call('setreg', reg)
	endtry
	return text
endfunction "}}}
function! s:Region.includes(expr, ...) abort "{{{
	if a:0 == 0 && type(a:expr) == v:t_dict
		let region = a:expr
		if region.head == s:NULLPOS || region.tail == s:NULLPOS
			return s:FALSE
		endif
		return s:{region.type}_is_included_in_{self.type}(region, self)
	endif
	try
		let region = call('s:Region', [a:expr] + a:000)
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:err_InvalidArgument('Region.includes')
	endtry
	return self.includes(region)
endfunction "}}}
function! s:Region.isinside(expr, ...) abort  "{{{
	if a:0 == 0 && type(a:expr) == v:t_dict
		let region = a:expr
		if region.head == s:NULLPOS || region.tail == s:NULLPOS
			return s:FALSE
		endif
		return s:{self.type}_is_included_in_{region.type}(self, region)
	endif
	try
		let region = call('s:Region', [a:expr] + a:000)
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:err_InvalidArgument('Region.isinside')
	endtry
	return self.isinside(region)
endfunction "}}}
function! s:Region.touches(expr, ...) abort "{{{
	if a:0 == 0 && type(a:expr) == v:t_dict
		let region = a:expr
		if region.head == s:NULLPOS || region.tail == s:NULLPOS
			return s:FALSE
		endif
		return s:{self.type}_is_touching_{region.type}(self, region)
	endif
	try
		let region = call('s:Region', [a:expr] + a:000)
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:err_InvalidArgument('Region.touches')
	endtry
	return self.touches(region)
endfunction "}}}

function! s:char_is_included_in_char(item, region) abort "{{{
	return !s:inorderof(a:item.head, a:region.head) &&
		\  !s:inorderof(a:region.tail, a:item.tail)
endfunction "}}}
function! s:char_is_included_in_line(item, region) abort "{{{
	return a:region.head[1] <= a:item.head[1] &&
		\  a:item.tail[1] <= a:region.tail[1]
endfunction "}}}
function! s:char_is_included_in_block(item, region) abort "{{{
	if !s:char_is_included_in_char(a:item, a:region)
		return s:FALSE
	endif

	if a:item.head[1] == a:item.tail[1]
		let itemleft = virtcol(a:item.head[1:2]) + a:item.head[3]
		let itemright = virtcol(a:item.tail[1:2]) + a:item.tail[3]
	else
		let itemleft = 1
		let lines = range(a:item.head[1], a:item.tail[1] - 1)
		let virtcoltaillist = map(lines, 'virtcol([v:val, "$"])')
		let virtcoltaillist += [virtcol(a:item.tail[1:2]) + a:item.tail[3]]
		let itemright = max(virtcoltaillist)
	endif
	let regionleft = virtcol(a:region.head[1:2]) + a:region.head[3]
	let regionright = virtcol(a:region.tail[1:2]) + a:region.tail[3]
	return regionleft <= itemleft && itemright <= regionright
endfunction "}}}
function! s:line_is_included_in_char(item, region) abort "{{{
	let item = s:Region(a:item.head, a:item.tail, 'line')
	let item.type = 'char'
	let item.tail[2] = col([item.tail[1], '$'])
	return s:char_is_included_in_char(item, a:region)
endfunction "}}}
function! s:line_is_included_in_line(item, region) abort "{{{
	return a:region.head[1] <= a:item.head[1] &&
		\  a:item.tail[1] <= a:region.tail[1]
endfunction "}}}
function! s:line_is_included_in_block(item, region) abort "{{{
	let item = s:Region(a:item.head, a:item.tail, 'line')
	let item.type = 'char'
	let item.tail[2] = col([item.tail[1], '$'])
	return s:char_is_included_in_block(item, a:region)
endfunction "}}}
function! s:block_is_included_in_char(item, region) abort "{{{
	return s:char_is_included_in_char(a:item, a:region)
endfunction "}}}
function! s:block_is_included_in_line(item, region) abort "{{{
	return s:char_is_included_in_line(a:item, a:region)
endfunction "}}}
function! s:block_is_included_in_block(item, region) abort "{{{
	if a:item.head[1] < a:region.head[1] || a:region.tail[1] < a:item.tail[1]
		return s:FALSE
	endif
	let itemleft = virtcol(a:item.head[1:2]) + a:item.head[3]
	let itemright = virtcol(a:item.tail[1:2]) + a:item.tail[3]
	let regionleft = virtcol(a:region.head[1:2]) + a:region.head[3]
	let regionright = virtcol(a:region.tail[1:2]) + a:region.tail[3]
	return regionleft <= itemleft && itemright <= regionright
endfunction "}}}
function! s:char_is_touching_char(item, region) abort "{{{
	return !(s:inorderof(a:item.tail, a:region.head) ||
	\        s:inorderof(a:region.tail, a:item.head))
endfunction "}}}
function! s:char_is_touching_line(item, region) abort "{{{
	return s:line_is_touching_line(a:item, a:region)
endfunction "}}}
function! s:char_is_touching_block(item, region) abort "{{{
	if s:inorderof(a:item.tail, a:region.head) ||
	\  s:inorderof(a:region.tail, a:item.head)
		return s:FALSE
	endif
	if a:item.tail[1] - a:item.head[1] >= 2
		return s:TRUE
	endif
	let itemleft = virtcol(a:item.head[1:2]) + a:item.head[3]
	let itemright = virtcol(a:item.tail[1:2]) + a:item.tail[3]
	let regionleft = virtcol(a:region.head[1:2]) + a:region.head[3]
	let regionright = virtcol(a:region.tail[1:2]) + a:region.tail[3]
	if a:item.tail[1] - a:item.head[1] == 1
		return !(itemright < regionleft && regionright < itemleft)
	endif
	return !(itemright < regionleft || regionright < itemleft)
endfunction "}}}
function! s:line_is_touching_char(item, region) abort "{{{
	return s:char_is_touching_line(a:region, a:item)
endfunction "}}}
function! s:line_is_touching_line(item, region) abort "{{{
	return !(a:item.tail[1] < a:region.head[1] ||
	\        a:region.tail[1] < a:item.head[1])
endfunction "}}}
function! s:line_is_touching_block(item, region) abort "{{{
	return s:line_is_touching_line(a:item, a:region)
endfunction "}}}
function! s:block_is_touching_char(item, region) abort "{{{
	return s:char_is_touching_block(a:region, a:item)
endfunction "}}}
function! s:block_is_touching_line(item, region) abort "{{{
	return s:line_is_touching_block(a:region, a:item)
endfunction "}}}
function! s:block_is_touching_block(item, region) abort "{{{
	if !s:line_is_touching_line(a:item, a:region)
		return s:FALSE
	endif
	let itemleft = virtcol(a:item.head[1:2]) + a:item.head[3]
	let itemright = virtcol(a:item.tail[1:2]) + a:item.tail[3]
	let regionleft = virtcol(a:region.head[1:2]) + a:region.head[3]
	let regionright = virtcol(a:region.tail[1:2]) + a:region.tail[3]
	return !(itemright < regionleft || regionright < itemleft)
endfunction "}}}
"}}}
" Item class (inherits Region class)"{{{
unlockvar! s:Item
let s:Item = {
	\	'__CLASS__': 'Item',
	\	'id': 0,
	\	'bufnr': 0,
	\	'_highlight': {},
	\	}
function! s:Item(expr, ...) abort "{{{
	let super = call('s:Region', [a:expr] + a:000)
	let sub = deepcopy(s:Item)
	try
		let item = s:ClassSys.inherit(sub, super)
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:err_InvalidArgument('Item')
	endtry

	let item.id = s:itemid()
	let item.bufnr = bufnr('%')
	let item._highlight = s:Highlights.Highlight()
	return item
endfunction "}}}
function! s:Item.show(higroup) abort "{{{
	if self._highlight.initialize(a:higroup, self)
		call self._highlight.quench()
	endif
	call self._highlight.show()
endfunction "}}}
function! s:Item.quench() abort "{{{
	call self._highlight.quench()
endfunction "}}}
function! s:Item._showlocal(higroup) abort "{{{
	if self._highlight.initialize(a:higroup, self)
		call self._highlight.quench()
		call self._highlight.show()
	else
		call self._highlight.showlocal()
	endif
endfunction "}}}
function! s:Item._quenchlocal() abort "{{{
	call self._highlight.quenchlocal()
endfunction "}}}
function! s:Item._histatus(winid) abort "{{{
	return self._highlight.status(a:winid)
endfunction "}}}
lockvar! s:Item

let s:itemid = 0
function! s:itemid() abort "{{{
	let s:itemid += 1
	return s:itemid
endfunction "}}}
"}}}
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
	let multiselector.higroup = get(options, 'higroup', s:HIGROUP)
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
		let newitem = call('s:Item', [a:expr] + a:000)
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:err_InvalidArgument('Multiselector.check')
	endtry
	call self.add(newitem)
	return newitem
endfunction "}}}
function! s:Multiselector.uncheck(expr, ...) abort  "{{{
	try
		let unchecked = call(self.emit_touching, [a:expr] + a:000, self)
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:err_InvalidArgument('Multiselector.uncheck')
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
		echoerr s:err_InvalidArgument('Multiselector.emit_inside')
	endtry
	return itemlist
endfunction "}}}
function! s:Multiselector.emit_touching(expr, ...) abort "{{{
	let args = [a:expr] + a:000
	try
		let itemlist = self.emit({_, item -> call(item.touches, args, item)})
	catch /^Vim(echoerr):multiselect: Invalid argument for/
		echoerr s:err_InvalidArgument('Multiselector.emit_touching')
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
	return s:inorderof(a:i1.head, a:i2.head) ? -1 : 1
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
	let extended = a:mode ==# 'x' && type ==# "\<C-v>" ? s:is_extended() : 0
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
	let region = s:Region(start, end)
	call setpos('.', region.head)

	let itemlist = []
	let head = s:searchpos(a:pat, 'cW')
	while head != s:NULLPOS && region.includes(head)
		let tail = s:searchpos(a:pat, 'ceW')
		if !region.includes(tail)
			break
		endif
		let newitem = s:Item(head, tail, 'v')
		call add(itemlist, newitem)
		if openfold is s:TRUE
			call s:foldopen(newitem.head[1])
		endif
		let head = s:searchpos(a:pat, 'W')
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
		let type = s:str2type(visualmode())
		let extended = type ==# 'block' ? s:is_extended() : s:FALSE
		let region = s:Region(getpos("'<"), getpos("'>"), type, extended)
		let item_in_visual = self.itemnum({_, item -> item.isinside(region)})
		if item_in_visual == 0
			if type ==# 'char'
				let pat = s:patternofselection(region)
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
function! s:is_extended() abort "{{{
	let view = winsaveview()
	normal! gv
	let extended = winsaveview().curswant == s:MAXCOL
	execute "normal! \<Esc>"
	call winrestview(view)
	return extended
endfunction
"}}}
function! s:searchpos(pat, flag) abort "{{{
	return [0] + searchpos(a:pat, a:flag) + [0]
endfunction "}}}
function! s:foldopen(lnum) abort "{{{
	if foldclosed(a:lnum) == -1
		return
	endif
	call cursor(a:lnum, 1)
	normal! zO
endfunction "}}}
function! s:patternofselection(region) abort "{{{
	let pat = ''
	let view = winsaveview()
	call setpos('.', a:region.head)
	if searchpos('\<', 'cn', line('.')) == a:region.head[1:2]
		let pat .= '\<'
	endif

	let pat .= substitute(escape(a:region.yank(), '\'), '\n', '\\n', 'g')

	call setpos('.', a:region.tail)
	if searchpos('.\>', 'cn', line('.')) == a:region.head[1:2]
		let pat .= '\>'
	endif
	call winrestview(view)
	return pat
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
	echoerr s:err_InvalidArgument('percolate')
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

function! s:str2type(str) abort "{{{
	if a:str ==# 'line' || a:str ==# 'V'
		return 'line'
	elseif a:str ==# 'block' || a:str[0] ==# "\<C-v>"
		return 'block'
	endif
	return 'char'
endfunction "}}}
function! s:str2visualcmd(str) abort "{{{
	if a:str ==# 'line' || a:str ==# 'V'
		return 'V'
	elseif a:str ==# 'block' || a:str[0] ==# "\<C-v>"
		return "\<C-v>"
	endif
	return 'v'
endfunction "}}}
function! s:inorderof(pos1, pos2) abort  "{{{
	return a:pos1[1] < a:pos2[1] || (a:pos1[1] == a:pos2[1] && a:pos1[2] + a:pos1[3] < a:pos2[2] + a:pos2[3])
endfunction "}}}
function! s:inbetween(pos, head, tail) abort  "{{{
	return a:pos != s:NULLPOS && a:head != s:NULLPOS && a:tail != s:NULLPOS
		\ && (a:pos[0] == a:head[0] && a:pos[0] == a:tail[0])
		\ && ((a:pos[1] > a:head[1]) || ((a:pos[1] == a:head[1]) && (a:pos[2] + a:pos[3] >= a:head[2] + a:head[3])))
		\ && ((a:pos[1] < a:tail[1]) || ((a:pos[1] == a:tail[1]) && (a:pos[2] + a:pos[3] <= a:tail[2] + a:tail[3])))
endfunction "}}}
function! s:err_InvalidArgument(name) abort "{{{
	return printf('multiselect: Invalid argument for %s()', a:name)
endfunction "}}}

" autocmd events{{{
" initialize if leaving the current buffer
" uncheck if the buffer is edited
augroup multiselect-events
	autocmd!
	autocmd BufLeave * call multiselect#_doautocmd('BufLeave')
	autocmd TabLeave * call multiselect#_doautocmd('TabLeave')
	autocmd CmdwinEnter * call multiselect#_doautocmd('CmdwinEnter')
	autocmd CmdwinLeave * call multiselect#_doautocmd('CmdwinLeave')
	autocmd TextChanged * call multiselect#_doautocmd('TextChanged')
	autocmd InsertEnter * call multiselect#_doautocmd('InsertEnter')
	autocmd WinNew * call multiselect#_doautocmd('WinNew')
augroup END

function! multiselect#_doautocmd(event) abort "{{{
	call filter(s:table, '!empty(v:val)')
	for ms in s:table
		call ms.event[a:event].trigger()
	endfor
endfunction "}}}
"}}}

" Multiselect module{{{
unlockvar! s:Multiselect
function! s:load() abort "{{{
	return s:multiselector
endfunction "}}}
let s:Multiselect = {
	\	'__MODULE__': 'Multiselect',
	\	'DEFAULTHIGHLIGHTGROUP': s:HIGROUP,
	\	'load': function('s:load'),
	\	'Region': function('s:Region'),
	\	'Item': function('s:Item'),
	\	'Multiselector': function('s:Multiselector'),
	\	'percolate': function('s:percolate'),
	\	'enumerate': function('s:enumerate'),
	\	'inorderof': function('s:inorderof'),
	\	'inbetween': function('s:inbetween'),
	\	'str2type': function('s:str2type'),
	\	'str2visualcmd': function('s:str2visualcmd'),
	\	}
lockvar! s:Multiselect
"}}}
let s:multiselector = s:Multiselect.Multiselector({
	\	'name': 'multiselect',
	\	'higroup': s:HIGROUP,
	\	'eventinit': 'MultiselectInit',
	\	'eventcheckpost': 'MultiselectCheckPost',
	\	'eventuncheckpost': 'MultiselectUncheckPost',
	\	})
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
