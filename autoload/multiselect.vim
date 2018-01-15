" multiselect.vim : A library for multiple selection
" TODO: better error messaging
let s:Highlights = multiselect#highlight#import()
let s:TRUE = 1
let s:FALSE = 0
let s:MAXCOL = 2147483647
let s:NULLPOS = [0, 0, 0, 0]
let s:HIGROUP = 'MultiselectCheckedItem'

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
function! s:Region(head, tail, ...) abort "{{{
	if a:head == s:NULLPOS || a:tail == s:NULLPOS || s:inorderof(a:tail, a:head)
		return {}
	endif

	let region = deepcopy(s:Region)
	let region.type = s:str2type(get(a:000, 0, 'char'))
	if region.type ==# 'line'
		let region.head = [0, a:head[1], 1, 0]
		let region.tail = [0, a:tail[1], s:MAXCOL, 0]
	else
		let region.head = copy(a:head)
		let region.tail = copy(a:tail)
	endif
	if region.type ==# 'block'
		let region.extended = get(a:000, 1, s:FALSE)
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
function! s:Region.isincluding(expr) abort "{{{
	let type_expr = type(a:expr)
	if type_expr == v:t_list
		let pos = a:expr
		if pos == s:NULLPOS
			return s:FALSE
		endif
		let region = s:Region(pos, pos, 'v')
		return self.isincluding(region)
	elseif type_expr == v:t_dict
		let region = a:expr
		if region.head == s:NULLPOS || region.tail == s:NULLPOS
			return s:FALSE
		endif
		return s:{region.type}_is_included_in_{self.type}(region, self)
	endif
	echoerr s:err_InvalidArgument('region.isincluding')
endfunction "}}}
function! s:Region.isinside(region) abort  "{{{
	if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS
		return s:FALSE
	endif
	return s:{self.type}_is_included_in_{a:region.type}(self, a:region)
endfunction "}}}
function! s:Region.istouching(expr) abort "{{{
	let type_expr = type(a:expr)
	if type_expr == v:t_list
		let pos = a:expr
		if pos == s:NULLPOS
			return s:FALSE
		endif
		let region = s:Region(pos, pos, 'v')
		return self.istouching(region)
	elseif type_expr == v:t_dict
		let range = a:expr
		if range.head == s:NULLPOS || range.tail == s:NULLPOS
			return s:FALSE
		endif
		return s:{self.type}_is_touching_{range.type}(self, range)
	endif
	echoerr s:err_InvalidArgument('region.istouching')
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
	\	'highlight': {},
	\	}
function! s:Item(head, tail, ...) abort "{{{
	let args = [a:head, a:tail] + a:000
	let item = s:inherit('Item', 'Region', args)
	if empty(item)
		return item
	endif

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
" Event class{{{
let s:ON = s:TRUE
let s:OFF = s:FALSE
unlockvar! s:Event
let s:eventid = 1
let s:Event = {
	\	'__CLASS__': 'Event',
	\	'name': '',
	\	'_state': s:OFF,
	\	'_orderlist': [],
	\	'_skipcount': -1,
	\	}
function! s:Event(name) abort "{{{
	let event = deepcopy(s:Event)
	let event.name = a:name
	return event
endfunction "}}}
function! s:Event.set(expr) abort "{{{
	let order = [s:eventid, type(a:expr), a:expr]
	call add(self._orderlist, order)
	let s:eventid += 1
	return order[0]
endfunction "}}}
function! s:Event.unset(id) abort "{{{
	call filter(self._orderlist, 'v:val[0] != a:id')
endfunction "}}}
function! s:Event.trigger() abort "{{{
	call self._decrement_skipcount()
	if !self.isactive()
		call self._check_skipcount()
		return
	endif

	for [_, type, l:Expr] in self._orderlist
		if type == v:t_string
			execute l:Expr
		elseif type == v:t_func
			call call(l:Expr, [self.name])
		endif
	endfor
endfunction "}}}
function! s:Event.on() abort "{{{
	let self._state = s:ON
	let self._skipcount = -1
	return self._state
endfunction "}}}
function! s:Event.off() abort "{{{
	let self._state = s:OFF
	let self._skipcount = -1
	return self._state
endfunction "}}}
function! s:Event.skip(...) abort "{{{
	let n = get(a:000, 0, 1)
	if n <= 0
		return
	endif
	call self.off()
	let self._skipcount = n
endfunction "}}}
function! s:Event.isactive() abort "{{{
	return self._state
endfunction "}}}
function! s:Event._decrement_skipcount() abort "{{{
	if self._state is s:ON
		return
	endif
	if self._skipcount > 0
		let self._skipcount -= 1
	endif
endfunction "}}}
function! s:Event._check_skipcount() abort "{{{
	if self._state is s:ON
		return
	endif
	if self._skipcount == 0
		call self.on()
	endif
endfunction "}}}
function! s:douserautocmd(name) abort "{{{
	if !exists('#User#' . a:name)
		return
	endif
	execute 'doautocmd <nomodeline> User ' . a:name
endfunction "}}}
lockvar! s:Event
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
	\		'BufLeave': s:Event('BufLeave'),
	\		'TabLeave': s:Event('TabLeave'),
	\		'CmdwinEnter': s:Event('CmdwinEnter'),
	\		'CmdwinLeave': s:Event('CmdwinLeave'),
	\		'TextChanged': s:Event('TextChanged'),
	\		'InsertEnter': s:Event('InsertEnter'),
	\		'WinNew': s:Event('WinNew'),
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
	let multiselector.event.Init = s:Event(EVENTINIT)
	let multiselector.event.CheckPost = s:Event(EVENTCHECKPOST)
	let multiselector.event.UncheckPost = s:Event(EVENTUNCHECKPOST)

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

" main interfaces
function! s:Multiselector.check(head, tail, ...) abort  "{{{
	let newitem = call('s:Item', [a:head, a:tail] + a:000)
	call self.add(newitem)
	return newitem
endfunction "}}}
function! s:Multiselector.uncheck(...) abort  "{{{
	if a:0 < 2
		" match by position
		let pos = get(a:000, 0, getpos('.'))
		let unchecked = self.emit_touching(pos)
	else
		" match by range
		let head = a:1
		let tail = a:2
		let region = s:Region(head, tail)
		let unchecked = self.emit_inside(region)
	endif
	return unchecked
endfunction "}}}
function! s:Multiselector.uncheckall() abort  "{{{
	return self.remove(0, -1)
endfunction "}}}
function! s:Multiselector.emit(...) abort "{{{
	if a:0
		let Filterexpr = a:1
		let filtered = s:percolate(self.itemlist, Filterexpr)
		if filtered != []
			call self._uncheckpost(filtered)
		endif
		return filtered
	endif
	return self.remove(0, -1)
endfunction "}}}
function! s:Multiselector.list(...) abort "{{{
	if a:0
		return s:percolate(copy(self.itemlist), a:1)
	endif
	return copy(self.itemlist)
endfunction "}}}
function! s:Multiselector.emit_inside(region) abort "{{{
	return self.emit({_, item -> item.isinside(a:region)})
endfunction "}}}
function! s:Multiselector.emit_touching(expr) abort "{{{
	return self.emit({_, item -> item.istouching(a:expr)})
endfunction "}}}
function! s:Multiselector.list_inside(region) abort "{{{
	return self.list({_, item -> item.isinside(a:region)})
endfunction "}}}
function! s:Multiselector.list_touching(expr) abort "{{{
	return self.list({_, item -> item.istouching(a:expr)})
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
	while head != s:NULLPOS && region.isincluding(head)
		let tail = s:searchpos(a:pat, 'ceW')
		if !region.isincluding(tail)
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
		call filter(itemlist, '!empty(v:val)')
		for newitem in itemlist
			call self.filter({_, olditem -> !newitem.istouching(olditem)})
		endfor
		call extend(self.itemlist, itemlist)
		call self._checkpost(itemlist)
	endif
	call winrestview(view)
endfunction "}}}
function! s:Multiselector.keymap_uncheck(mode) abort "{{{
	if a:mode ==# 'x'
		call s:multiselector.uncheck(getpos("'<"), getpos("'>"))
	else
		call s:multiselector.uncheck()
	endif
endfunction "}}}
function! s:Multiselector.keymap_uncheckall() abort "{{{
	call s:multiselector.uncheckall()
endfunction "}}}
function! s:Multiselector.keymap_undo() abort "{{{
	let last = self.lastevent()
	if last.event ==# 'check'
		let removed = []
		for checked in last.itemlist
			let i = self.search(checked)
			if i != -1
				call add(removed, remove(self.itemlist, i))
			endif
		endfor
		call self._uncheckpost(removed)
	elseif last.event ==# 'uncheck'
		call self.extend(last.itemlist)
	endif
endfunction "}}}
function! s:Multiselector.keymap_select(mode) abort "{{{
	let itemlist = []
	if a:mode ==# 'x'
		let type = visualmode()
		let extended = type[0] ==# "\<C-v>" ? s:is_extended() : s:FALSE
		let region = s:Region(getpos("'<"), getpos("'>"), type, extended)
		let itemlist = s:multiselector.list({_, item -> item.isinside(region)})
		if empty(itemlist)
			call self.keymap_check(a:mode)
		else
			if len(itemlist) < s:multiselector.itemnum()
				call s:multiselector.emit({_, item -> !item.isinside(region)})
			endif
		endif
		return
	else
		let curpos = getpos('.')
		let itemlist = s:multiselector.emit_touching(curpos)
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

" low-level interfaces
function! s:Multiselector.extend(itemlist) abort "{{{
	if empty(a:itemlist)
		return self.itemlist
	endif

	let added = []
	for newitem in a:itemlist
		if empty(newitem) || newitem.bufnr != self.bufnr
			continue
		endif
		call self.filter({_, olditem -> !newitem.istouching(olditem)})
		call add(self.itemlist, newitem)
		call add(added, newitem)
	endfor
	call self._checkpost(added)
	return self.itemlist
endfunction "}}}
function! s:Multiselector.add(item) abort "{{{
	return self.extend([a:item])
endfunction "}}}
function! s:Multiselector.remove(i, ...) abort "{{{
	if self.itemnum() == 0
		return []
	endif

	if a:0
		let removed = remove(self.itemlist, a:i, a:1)
		call self._uncheckpost(removed)
		return removed
	endif
	let removed = remove(self.itemlist, a:i)
	call self._uncheckpost([removed])
	return removed
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
	let l:Filterexpr = a:1
	return len(filter(copy(self.itemlist), l:Filterexpr))
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
	if a:0
		let Filterexpr = a:1
		let itemlist = self.list(Filterexpr)
	else
		let itemlist = self.itemlist
	endif
	for item in itemlist
		call item.show(self.higroup)
	endfor
endfunction "}}}
function! s:Multiselector.quench(...) abort "{{{
	if a:0
		let Filterexpr = a:1
		let itemlist = self.list(Filterexpr)
	else
		let itemlist = self.itemlist
	endif
	for item in self.itemlist
		call item.quench()
	endfor
endfunction "}}}
function! s:percolate(iter, Filterexpr) abort "{{{
	let i = len(a:iter) - 1
	let filtered = []
	if type(a:iter) == v:t_list
		while i >= 0
			if call(a:Filterexpr, [i, a:iter[i]])
				call add(filtered, remove(a:iter, i))
			endif
			let i -= 1
		endwhile
	elseif type(a:iter) == v:t_dict
		for [key, val] in items(a:iter)
			if call(a:Filterexpr, [key, val])
				call add(filtered, remove(a:iter, key))
			endif
		endfor
	else
		echoerr s:err_InvalidArgument('percolate')
	endif
	return filtered
endfunction "}}}

" private methods
function! s:Multiselector._initialize(...) abort "{{{
	let self.bufnr = bufnr('%')
	call self.uncheckall()
	call self.event.Init.trigger()
endfunction "}}}
function! s:Multiselector._suspend(...) abort "{{{
	let self._pending.bufnr = self.bufnr
	let self._pending.itemlist = self.itemlist
	let self._pending._last = self._last
	let self.bufnr = bufnr('%')
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
	for item in a:added
		call item.show(self.higroup)
	endfor
	let self._last.event = 'check'
	let self._last.itemlist = a:added
	call self.event.CheckPost.trigger()
endfunction "}}}
function! s:Multiselector._uncheckpost(removed) abort "{{{
	for item in a:removed
		call item.quench()
	endfor
	let self._last.event = 'uncheck'
	let self._last.itemlist = a:removed
	call self.event.UncheckPost.trigger()
endfunction "}}}
lockvar! s:Multiselector
"}}}

function! s:inherit(subname, supername, args) abort "{{{
	let super = call('s:' . a:supername, a:args)
	if empty(super)
		return super
	endif

	let sub = deepcopy(s:[a:subname])
	call extend(sub, super, 'keep')
	let sub.__SUPER__ = {}
	for [key, l:Val] in items(super)
		if type(l:Val) == v:t_func || key ==# '__SUPER__'
			let sub.__SUPER__[key] = l:Val
		endif
	endfor
	return sub
endfunction "}}}
function! s:super(sub, ...) abort "{{{
	if !has_key(a:sub, '__SUPER__')
		return {}
	endif

	let level = get(a:000, 0, 1)
	let supermethods = a:sub
	for _ in range(level)
		let supermethods = supermethods.__SUPER__
	endfor

	let super = {}
	for [key, l:Val] in items(supermethods)
		if type(l:Val) == v:t_func
			let super[key] = function('s:supercall', [a:sub, l:Val])
		endif
	endfor
	return super
endfunction "}}}
function! s:supercall(sub, Funcref, ...) abort "{{{
	return call(a:Funcref, a:000, a:sub)
endfunction "}}}
function! s:str2type(str) abort "{{{
	if a:str ==# 'line' || a:str ==# 'V'
		return 'line'
	elseif a:str ==# 'block' || a:str[0] ==# "\<C-v>"
		return 'block'
	endif
	return 'char'
endfunction "}}}
function! s:str2visualcmd(str) abort "{{{
	if a:str ==# 'line' || a:str[0] ==# 'V'
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

" highlight group{{{
function! s:default_highlight() abort
	if hlexists('VisualNOS')
		highlight default link MultiselectCheckedItem VisualNOS
	elseif hlexists('Visual')
		highlight default link MultiselectCheckedItem Visual
	else
		highlight default MultiselectCheckedItem cterm=reverse gui=reverse
	endif
endfunction
call s:default_highlight()

augroup multiselect-highlgiht
	autocmd!
	autocmd ColorScheme * call s:default_highlight()
augroup END
"}}}
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
	\	'inorderof': function('s:inorderof'),
	\	'inbetween': function('s:inbetween'),
	\	'str2type': function('s:str2type'),
	\	'str2visualcmd': function('s:str2visualcmd'),
	\	'super': function('s:super'),
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
