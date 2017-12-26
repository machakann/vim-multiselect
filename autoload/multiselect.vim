" multiselect.vim : An library for multiple selection
" TODO: better error messaging
let s:Highlights = multiselect#highlight#import()
let s:TRUE = 1
let s:FALSE = 0
let s:MAXCOL = 2147483647
let s:NULLPOS = [0, 0, 0, 0]
let s:HIGROUP = 'MultiselectCheckedItem'
let s:EVENTCHECKPOST = 'MultiselectCheckPost'
let s:EVENTUNCHECKPOST = 'MultiselectUncheckPost'

let s:table = []

function! multiselect#import() abort "{{{
	return s:MultiselectModule
endfunction "}}}

" Region class{{{
let s:Region = {
	\	'__CLASS__': 'Region',
	\	'head': copy(s:NULLPOS),
	\	'tail': copy(s:NULLPOS),
	\	'type': 'v',
	\	'extended': s:FALSE,
	\	}
function! s:Region(head, tail, ...) abort "{{{
	if type(a:head) == v:t_number && type(a:tail) == v:t_number
		let region = deepcopy(s:Region)
		let region.head = [0, a:head, 1, 0]
		let region.tail = [0, a:tail, col([a:tail, '$']), 0]
		let region.type = 'V'
		return region
	elseif type(a:head) == v:t_list && type(a:tail) == v:t_list
		let region = deepcopy(s:Region)
		let region.type = s:str2v(get(a:000, 0, 'v'))
		if region.type ==# 'V'
			let region.head = [0, a:head[1], 1, 0]
			let region.tail = [0, a:tail[1], col([a:tail[1], '$']), 0]
		else
			let region.head = copy(a:head)
			let region.tail = copy(a:tail)
		endif
		if region.type ==# "\<C-v>"
			let region.extended = get(a:000, 1, s:FALSE)
		endif
		return region
	endif
	echoerr s:err_InvalidArgument('s:Region')
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
function! s:Item(bufnr, head, tail, type, ...) abort "{{{
	if !bufexists(a:bufnr)
		return {}
	endif
	if a:head == s:NULLPOS || a:tail == s:NULLPOS || s:inorderof(a:tail, a:head)
		return {}
	endif

	let origin = s:Region(a:head, a:tail, a:type, get(a:000, 0, s:FALSE))
	let item = extend(origin, deepcopy(s:Item), 'force')
	let item.id = s:itemid()
	let item.bufnr = a:bufnr
	let item.highlight = s:Highlights.Highlight()
	return item
endfunction "}}}
function! s:Item.isinside(region) abort  "{{{
	let itemtype = s:type2typestring(self.type)
	let rangetype = s:type2typestring(a:region.type)
	return s:{itemtype}_is_included_in_{rangetype}(self, a:region)
endfunction "}}}
function! s:Item.istouching(expr) abort "{{{
	let type_expr = type(a:expr)
	if type_expr == v:t_number
		let lnum = a:expr
		return self.head[1] <= lnum && lnum <= self.tail[1]
	elseif type_expr == v:t_list
		let pos = a:expr
		let region = s:Region(pos, pos, 'v')
		return self.istouching(region)
	elseif type_expr == v:t_dict
		let itemtype = s:type2typestring(self.type)
		let rangetype = s:type2typestring(a:expr.type)
		return s:{itemtype}_is_touching_{rangetype}(self, a:expr)
	endif
	echoerr s:err_InvalidArgument('item.istouching')
endfunction "}}}
function! s:Item.select() abort "{{{
	execute 'normal! ' . self.type
	call setpos('.', self.head)
	normal! o
	call setpos('.', self.tail)
	if self.extended
		normal! $
	endif
endfunction "}}}
function! s:Item.show(higroup) abort "{{{
	if self.highlight.initialize(a:higroup, self)
		call self.highlight.quench()
	endif
	call self.highlight.show()
endfunction "}}}
function! s:Item.quench() abort "{{{
	call self.highlight.quench()
endfunction "}}}
function! s:Item._showlocal(higroup) abort "{{{
	if self.highlight.initialize(a:higroup, self)
		call self.highlight.quench()
		call self.highlight.show()
	else
		call self.highlight.showlocal()
	endif
endfunction "}}}
function! s:Item._quenchlocal() abort "{{{
	call self.highlight.quenchlocal()
endfunction "}}}
function! s:Item._histatus(winid) abort "{{{
	return self.highlight.status(a:winid)
endfunction "}}}
lockvar! s:Item

let s:itemid = 0
function! s:itemid() abort "{{{
	let s:itemid += 1
	return s:itemid
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
	let item = s:Region(a:item.head[1], a:item.tail[1])
	let item.type = 'v'
	return s:char_is_included_in_char(item, a:region)
endfunction "}}}
function! s:line_is_included_in_line(item, region) abort "{{{
	return a:region.head[1] <= a:item.head[1] &&
		\  a:item.tail[1] <= a:region.tail[1]
endfunction "}}}
function! s:line_is_included_in_block(item, region) abort "{{{
	let item = s:Region(a:item.head[1], a:item.tail[1])
	let item.type = 'v'
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
" Event class{{{
let s:ON = s:TRUE
let s:OFF = s:FALSE
unlockvar! s:Event
let s:Event = {
	\	'__CLASS__': 'Event',
	\	'name': '',
	\	'state': s:OFF,
	\	'_skipcount': 0,
	\	}
function! s:Event(name) abort "{{{
	let event = deepcopy(s:Event)
	let event.name = a:name
	call event.on()
	return event
endfunction "}}}
function! s:Event.on() abort "{{{
	let self.state = s:ON
	let self._skipcount = 0
	return self.state
endfunction "}}}
function! s:Event.off() abort "{{{
	let self.state = s:OFF
	let self._skipcount = 0
	return self.state
endfunction "}}}
function! s:Event.skip(...) abort "{{{
	let n = get(a:000, 0, 1)
	if n <= 0
		return
	endif
	call self.off()
	let self._skipcount = n
endfunction "}}}
function! s:Event.is_active() abort "{{{
	return self.state
endfunction "}}}
function! s:Event._tic() abort "{{{
	if self.state is s:ON
		return
	endif
	if self._skipcount <= 0
		call self.on()
	endif
	let self._skipcount -= 1
endfunction "}}}
lockvar! s:Event
"}}}
" Multiselector class "{{{
unlockvar! s:Multiselector
let s:Multiselector = {
	\	'__CLASS__': 'Multiselector',
	\	'_bufnr': -1,
	\	'itemlist': [],
	\	'higroup': '',
	\	'last':{
	\			'event': '',
	\			'itemlist': [],
	\		},
	\	'event': {
	\			'BufLeave': s:Event('BufLeave'),
	\			'TabLeave': s:Event('TabLeave'),
	\			'CmdwinLeave': s:Event('CmdwinLeave'),
	\			'TextChanged': s:Event('TextChanged'),
	\			'InsertEnter': s:Event('InsertEnter'),
	\			'WinNew': s:Event('WinNew'),
	\		},
	\	}
function! s:Multiselector(...) abort "{{{
	let multiselector = deepcopy(s:Multiselector)
	let multiselector.higroup = get(a:000, 0, s:HIGROUP)
	let multiselector._bufnr = bufnr('%')
	call add(s:table, multiselector)
	return multiselector
endfunction "}}}

" main interfaces
function! s:Multiselector.check(head, tail, type, ...) abort  "{{{
	let extended = a:type ==# "\<C-v>" ? get(a:000, 0, 0) : 0
	let newitem = s:Item(self._bufnr, a:head, a:tail, a:type, extended)
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
		let unchecked = self.emit_includedin(head, tail)
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
	call self.emit(a:Filterexpr)
	return self.itemlist
endfunction
"}}}
function! s:Multiselector.sort(...) abort "{{{
	let itemlist = a:0 ? a:1 : self.itemlist
	return sort(copy(itemlist), 's:sort_items')
endfunction "}}}
function! s:Multiselector.isempty() abort "{{{
	return empty(self.itemlist)
endfunction "}}}
function! s:sort_items(i1, i2) abort "{{{
	if a:i1.head == a:i2.head
		return 0
	endif
	return s:inorderof(a:i1.head, a:i2.head) ? -1 : 1
endfunction "}}}

" low-level interfaces
function! s:Multiselector.get(i, ...) abort "{{{
	let default = get(a:000, 0, 0)
	return get(self.itemlist, a:i, default)
endfunction "}}}
function! s:Multiselector.extend(itemlist) abort "{{{
	if empty(a:itemlist)
		return self.itemlist
	endif

	let added = []
	for item in a:itemlist
		if empty(item)
			continue
		endif
		call self._merge(item)
		call add(self.itemlist, item)
		call add(added, item)
	endfor
	call self._checkpost(added)
	return self.itemlist
endfunction "}}}
function! s:Multiselector.add(item) abort "{{{
	return self.extend([a:item])
endfunction "}}}
function! s:Multiselector.remove(i, ...) abort	"{{{
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
function! s:Multiselector.bufnr() abort "{{{
	return self._bufnr
endfunction "}}}
function! s:Multiselector.itemnum() abort "{{{
	return len(self.itemlist)
endfunction "}}}
function! s:Multiselector.lastevent() abort "{{{
	let last = copy(self.last)
	let last.itemlist = copy(self.last.itemlist)
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
function! s:doautocmd(event) abort "{{{
	if !exists('#User#' . a:event)
		return
	endif
	execute 'doautocmd <nomodeline> User ' . a:event
endfunction "}}}

" private methods
function! s:Multiselector._initialize() abort "{{{
	let self._bufnr = bufnr('%')
	call self.uncheckall()
	let self.last.event = ''
	let self.last.itemlist = []
	for event in values(self.event)
		call event.on()
	endfor
endfunction "}}}
function! s:Multiselector._merge(newitem) abort "{{{
	let mergeable = s:TRUE
	while mergeable
		let type = s:type2typestring(a:newitem.type)
		let i = self.itemnum() - 1
		let mergeable = s:FALSE
		while i >= 0
			let item = self.get(i)
			let itemtype = s:type2typestring(item.type)
			let mergeable = s:merge_{type}_{itemtype}(a:newitem, item)
			if mergeable
				call self.remove(i)
				break
			endif
			let i -= 1
		endwhile
	endwhile
	return a:newitem
endfunction "}}}
function! s:Multiselector._checkpost(added) abort "{{{
	for item in a:added
		call item.show(self.higroup)
	endfor
	let self.last.event = 'check'
	let self.last.itemlist = a:added
	call s:doautocmd(s:EVENTCHECKPOST)
endfunction "}}}
function! s:Multiselector._uncheckpost(removed) abort "{{{
	for item in a:removed
		call item.quench()
	endfor
	let self.last.event = 'uncheck'
	let self.last.itemlist = a:removed
	call s:doautocmd(s:EVENTUNCHECKPOST)
endfunction "}}}
lockvar! s:Multiselector

" conflict resolving (in Multiselector.add)
" NOTE: These functions are destructive for 'newitem'.
function! s:merge_char_char(newitem, item) abort "{{{
	if !a:newitem.istouching(a:item)
		return s:FALSE
	endif
	let a:newitem.head = s:get_former(a:item.head, a:newitem.head)
	let a:newitem.tail = s:get_latter(a:item.tail, a:newitem.tail)
	return s:TRUE
endfunction "}}}
function! s:merge_char_line(newitem, item) abort "{{{
	return s:merge_char_char(a:newitem, a:item)
endfunction "}}}
function! s:merge_char_block(newitem, item) abort "{{{
	return a:newitem.istouching(a:item)
endfunction "}}}
function! s:merge_line_char(newitem, item) abort "{{{
	if !a:newitem.istouching(a:item)
		return s:FALSE
	endif
	let lineend = a:newitem.tail[2]
	let a:newitem.head = s:get_former(a:item.head, a:newitem.head)
	let a:newitem.tail = s:get_latter(a:item.tail, a:newitem.tail)
	let a:newitem.head[2] = 1
	let a:newitem.tail[2] = lineend
	return s:TRUE
endfunction "}}}
function! s:merge_line_line(newitem, item) abort "{{{
	if !a:newitem.istouching(a:item)
		return s:FALSE
	endif
	let a:newitem.head = s:get_former(a:item.head, a:newitem.head)
	let a:newitem.tail = s:get_latter(a:item.tail, a:newitem.tail)
	return s:TRUE
endfunction "}}}
function! s:merge_line_block(newitem, item) abort "{{{
	return a:newitem.istouching(a:item)
endfunction "}}}
function! s:merge_block_char(newitem, item) abort "{{{
	return a:newitem.istouching(a:item)
endfunction "}}}
function! s:merge_block_line(newitem, item) abort "{{{
	return a:newitem.istouching(a:item)
endfunction "}}}
function! s:merge_block_block(newitem, item) abort "{{{
	if !a:newitem.istouching(a:item)
		return s:FALSE
	endif
	let a:newitem.head = s:get_former(a:item.head, a:newitem.head)
	let a:newitem.tail = s:get_latter(a:item.tail, a:newitem.tail)
	return s:TRUE
endfunction "}}}
function! s:type2typestring(type) abort "{{{
	if a:type ==# 'v'
		return 'char'
	elseif a:type ==# 'V'
		return 'line'
	elseif a:type[0] ==# "\<C-v>"
		return 'block'
	endif
	return a:type
endfunction "}}}
function! s:get_former(pos1, pos2) abort "{{{
	return s:inorderof(a:pos1, a:pos2) ? a:pos1 : a:pos2
endfunction "}}}
function! s:get_latter(pos1, pos2) abort "{{{
	return s:inorderof(a:pos1, a:pos2) ? a:pos2 : a:pos1
endfunction "}}}
"}}}

" keymapping interfaces
function! multiselect#check(mode) abort  "{{{
	let head = getpos("'<")
	let tail = getpos("'>")
	let type = visualmode()[0]
	let extended = type ==# "\<C-v>" ? s:is_extended() : 0
	call s:multiselector.check(head, tail, type, extended)
endfunction "}}}
function! multiselect#uncheck(mode) abort  "{{{
	if a:mode ==# 'n'
		call s:multiselector.uncheck()
	elseif a:mode ==# 'x'
		call s:multiselector.uncheck(getpos("'<"), getpos("'>"))
	endif
endfunction "}}}
function! multiselect#uncheckall(mode) abort  "{{{
	return s:multiselector.uncheckall()
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

function! s:str2v(str) abort "{{{
	if a:str[0] ==# 'V' || a:str ==# 'line'
		return 'V'
	elseif a:str[0] ==# "\<C-v>" || a:str ==# 'block'
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
	autocmd BufLeave * call multiselect#_event_initializeall('BufLeave')
	autocmd TabLeave * call multiselect#_event_initializeall('TabLeave')
	autocmd CmdwinLeave * call multiselect#_event_initializeall('CmdwinLeave')
	autocmd TextChanged * call multiselect#_event_uncheckall('TextChanged')
	autocmd InsertEnter * call multiselect#_event_uncheckall('InsertEnter')
	autocmd WinNew * call multiselect#_event_highlight('WinNew')
augroup END

function! multiselect#_event_uncheckall(event) abort "{{{
	for ms in s:table
		call ms.event[a:event]._tic()
		if ms.event[a:event].is_active()
			call ms.uncheckall()
		endif
	endfor
endfunction "}}}
function! multiselect#_event_initializeall(event) abort "{{{
	for ms in s:table
		call ms.event[a:event]._tic()
		if ms.event[a:event].is_active()
			call ms._initialize()
		endif
	endfor
endfunction "}}}
function! multiselect#_event_highlight(event) abort "{{{
	let winid = win_getid()
	for ms in s:table
		call ms.event[a:event]._tic()
		if !ms.event[a:event].is_active()
			continue
		endif

		for item in ms.itemlist
			if item._histatus(winid) is s:Highlights.OFF
				call item._showlocal(ms.higroup)
			endif
		endfor
	endfor
endfunction "}}}
"}}}

" Multiselect module{{{
unlockvar! s:MultiselectModule
let s:MultiselectModule = {
	\	'__MODULE__': 'Multiselect',
	\	'DEFAULTHIGHLIGHTGROUP': s:HIGROUP,
	\	'EVENTCHECKPOST': s:EVENTCHECKPOST,
	\	'EVENTUNCHECKPOST': s:EVENTUNCHECKPOST,
	\	'Region': function('s:Region'),
	\	'Item': function('s:Item'),
	\	'Multiselector': function('s:Multiselector'),
	\	'percolate': function('s:percolate'),
	\	'inorderof': function('s:inorderof'),
	\	'inbetween': function('s:inbetween'),
	\	'str2v': function('s:str2v'),
	\	}
function! s:MultiselectModule.load() abort "{{{
	return s:multiselector
endfunction "}}}
lockvar! s:MultiselectModule
"}}}
let s:multiselector = s:MultiselectModule.Multiselector()
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
