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
	return s:MultiselectModule
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
function! s:Item(head, tail, type, ...) abort "{{{
	let args = [a:head, a:tail, a:type, get(a:000, 0, s:FALSE)]
	let item = s:inherit('Region', 'Item', args)
	if empty(item)
		return item
	endif

	let item.id = s:itemid()
	let item.bufnr = bufnr('%')
	let item.highlight = s:Highlights.Highlight()
	return item
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
"}}}
" Event class{{{
let s:ON = s:TRUE
let s:OFF = s:FALSE
unlockvar! s:Event
let s:Event = {
	\	'__CLASS__': 'Event',
	\	'name': '',
	\	'state': s:OFF,
	\	'_skipcount': -1,
	\	}
function! s:Event(name) abort "{{{
	let event = deepcopy(s:Event)
	let event.name = a:name
	return event
endfunction "}}}
function! s:Event.on() abort "{{{
	let self.state = s:ON
	let self._skipcount = -1
	return self.state
endfunction "}}}
function! s:Event.off() abort "{{{
	let self.state = s:OFF
	let self._skipcount = -1
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
function! s:Event.isactive() abort "{{{
	return self.state
endfunction "}}}
function! s:Event._decrement_skipcount() abort "{{{
	if self.state is s:ON
		return
	endif
	if self._skipcount > 0
		let self._skipcount -= 1
	endif
endfunction "}}}
function! s:Event._check_skipcount() abort "{{{
	if self.state is s:ON
		return
	endif
	if self._skipcount == 0
		call self.on()
	endif
endfunction "}}}
lockvar! s:Event
"}}}
" UniqueEvent class (inherits Event class){{{
let s:UniqueEvent = {
	\	'__CLASS__': 'UniqueEvent',
	\	'eventdefinition': '',
	\	'doautocmd': '',
	\	}
function! s:UniqueEvent(name) abort "{{{
	let uniqueevent = s:inherit('Event', 'UniqueEvent', [a:name])
	if empty(a:name)
		call uniqueevent.off()
	else
		let uniqueevent.eventdefinition = '#User#' . a:name
		let uniqueevent.doautocmd = 'doautocmd <nomodeline> User ' . a:name
	endif
	return uniqueevent
endfunction "}}}
function! s:UniqueEvent.on() abort "{{{
	if empty(self.name)
		return
	endif
	call self.super_on()
endfunction "}}}
function! s:UniqueEvent.trigger() abort "{{{
	if empty(self.doautocmd) || !self.isdefined()
		return
	endif

	call self._decrement_skipcount()
	if !self.isactive()
		call self._check_skipcount()
		return
	endif

	execute self.doautocmd
endfunction "}}}
function! s:UniqueEvent.isdefined() abort "{{{
	if empty(self.eventdefinition)
		return s:FALSE
	endif
	return exists(self.eventdefinition)
endfunction "}}}
"}}}
" Multiselector class "{{{
unlockvar! s:Multiselector
let s:Multiselector = {
	\	'__CLASS__': 'Multiselector',
	\	'bufnr': -1,
	\	'itemlist': [],
	\	'name': '',
	\	'higroup': '',
	\	'last':{
	\		'event': '',
	\		'itemlist': [],
	\		},
	\	'event': {
	\		'BufLeave': s:Event('BufLeave'),
	\		'TabLeave': s:Event('TabLeave'),
	\		'CmdwinLeave': s:Event('CmdwinLeave'),
	\		'TextChanged': s:Event('TextChanged'),
	\		'InsertEnter': s:Event('InsertEnter'),
	\		'WinNew': s:Event('WinNew'),
	\		'Init': {},
	\		'CheckPost': {},
	\		'UncheckPost': {},
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
	let multiselector.event.Init = s:UniqueEvent(EVENTINIT)
	let multiselector.event.CheckPost = s:UniqueEvent(EVENTCHECKPOST)
	let multiselector.event.UncheckPost = s:UniqueEvent(EVENTUNCHECKPOST)

	call add(s:table, multiselector)
	call multiselector._initialize()
	return multiselector
endfunction "}}}

" main interfaces
function! s:Multiselector.check(head, tail, type, ...) abort  "{{{
	if s:str2type(a:type) ==# 'block'
		let extended = get(a:000, 0, 0)
	else
		let extended = 0
	endif
	let newitem = s:Item(a:head, a:tail, a:type, extended)
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
	return s:inorderof(a:i1.head, a:i2.head) ? -1 : 1
endfunction "}}}

" keymap interfaces
function! s:Multiselector.keymap_check(mode) abort "{{{
	if a:mode ==# 'n'
		normal! zOviw
		execute "normal! \<Esc>"
	endif
	let head = getpos("'<")
	let tail = getpos("'>")
	let type = visualmode()
	let extended = a:mode ==# 'x' && type ==# "\<C-v>" ? s:is_extended() : 0
	let newitem = self.check(head, tail, type, extended)
	call s:foldopen(newitem.head[1])
endfunction "}}}
function! s:Multiselector.keymap_checkpattern(mode, pat) abort "{{{
	if empty(a:pat)
		return
	endif

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

	let head = s:searchpos(a:pat, 'cW')
	if head == s:NULLPOS || !region.isincluding(head)
		call winrestview(view)
		return
	endif
	while 1
		let tail = s:searchpos(a:pat, 'ceW')
		if !region.isincluding(tail)
			break
		endif
		let newitem = self.check(head, tail, 'v')
		call s:foldopen(newitem.head[1])
		let head = s:searchpos(a:pat, 'W')
		if head == s:NULLPOS || !region.isincluding(head)
			break
		endif
	endwhile
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
function! s:Multiselector.keymap_toggle(mode) abort "{{{
	let itemlist = []
	if a:mode ==# 'x'
		let selectedregion = s:Region(getpos("'<"), getpos("'>"))
		let itemlist = s:multiselector.emit_inside(selectedregion)
	else
		let curpos = getpos('.')
		let itemlist = s:multiselector.emit_touching(curpos)
	endif
	if empty(itemlist)
		call self.keymap_check(a:mode)
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
	if g:multiselect#keymap#openfold is s:FALSE
		return
	endif
	if a:lnum == 0 || foldclosed(a:lnum) == -1
		return
	endif

	let view = winsaveview()
	call cursor(a:lnum, 1)
	normal! zO
	call winrestview(view)
endfunction "}}}

" low-level interfaces
function! s:Multiselector.extend(itemlist) abort "{{{
	if empty(a:itemlist)
		return self.itemlist
	endif

	let added = []
	for newitem in a:itemlist
		if empty(newitem)
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
function! s:Multiselector.itemnum() abort "{{{
	return len(self.itemlist)
endfunction "}}}
function! s:Multiselector.isempty() abort "{{{
	return empty(self.itemlist)
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

" private methods
function! s:Multiselector._initialize() abort "{{{
	let self.bufnr = bufnr('%')
	call self.uncheckall()
	let self.last.event = ''
	let self.last.itemlist = []
	for event in values(self.event)
		call event.on()
	endfor
	call self.event.Init.trigger()
endfunction "}}}
function! s:Multiselector._checkpost(added) abort "{{{
	for item in a:added
		call item.show(self.higroup)
	endfor
	let self.last.event = 'check'
	let self.last.itemlist = a:added
	call self.event.CheckPost.trigger()
endfunction "}}}
function! s:Multiselector._uncheckpost(removed) abort "{{{
	for item in a:removed
		call item.quench()
	endfor
	let self.last.event = 'uncheck'
	let self.last.itemlist = a:removed
	call self.event.UncheckPost.trigger()
endfunction "}}}
lockvar! s:Multiselector
"}}}

function! s:inherit(supername, subname, args) abort "{{{
	let Constructor_super = 's:' . a:supername
	let super = call(Constructor_super, a:args)
	if empty(super)
		return super
	endif

	let sub = deepcopy(s:[a:subname])
	call extend(sub, super, 'keep')
	" FIXME: Please find out a better way to handle super class methods
	let sub.super = {}
	for [key, l:Val] in items(super)
		if type(l:Val) == v:t_func
			let sub['super_' . key] = l:Val
		endif
	endfor
	return sub
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
	autocmd BufLeave * call multiselect#_event_initializeall('BufLeave')
	autocmd TabLeave * call multiselect#_event_initializeall('TabLeave')
	autocmd CmdwinLeave * call multiselect#_event_initializeall('CmdwinLeave')
	autocmd TextChanged * call multiselect#_event_uncheckall('TextChanged')
	autocmd InsertEnter * call multiselect#_event_uncheckall('InsertEnter')
	autocmd WinNew * call multiselect#_event_highlight('WinNew')
augroup END

function! multiselect#_event_uncheckall(event) abort "{{{
	for ms in s:table
		call ms.event[a:event]._decrement_skipcount()
		if !ms.event[a:event].isactive()
			call ms.event[a:event]._check_skipcount()
			continue
		endif
		call ms.uncheckall()
	endfor
endfunction "}}}
function! multiselect#_event_initializeall(event) abort "{{{
	for ms in s:table
		call ms.event[a:event]._decrement_skipcount()
		if !ms.event[a:event].isactive()
			call ms.event[a:event]._check_skipcount()
			continue
		endif
		call ms._initialize()
	endfor
endfunction "}}}
function! multiselect#_event_highlight(event) abort "{{{
	let winid = win_getid()
	for ms in s:table
		call ms.event[a:event]._decrement_skipcount()
		if !ms.event[a:event].isactive()
			call ms.event[a:event]._check_skipcount()
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
function! s:load() abort "{{{
	return s:multiselector
endfunction "}}}
let s:MultiselectModule = {
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
	\	}
lockvar! s:MultiselectModule
"}}}
let s:multiselector = s:MultiselectModule.Multiselector({
	\	'name': 'multiselect',
	\	'higroup': s:HIGROUP,
	\	'eventinit': 'MultiselectInit',
	\	'eventcheckpost': 'MultiselectCheckPost',
	\	'eventuncheckpost': 'MultiselectUncheckPost',
	\	})
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
