let s:ClassSys = multiselect#ClassSys#_import()
let s:Errors = multiselect#Errors#_import()
let s:Highlights = multiselect#Highlights#_import()
let s:TRUE = 1
let s:FALSE = 0
let s:MAXCOL = 2147483647
let s:NULLPOS = [0, 0, 0, 0]

" Region class{{{
unlockvar! s:Region
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
		if t_expr is v:t_number
			let lnum = a:expr
			let head = [0, lnum, 1, 0]
			let tail = [0, lnum, s:MAXCOL, 0]
			let type = 'line'
		elseif t_expr is v:t_list
			let pos = a:expr
			let head = copy(pos)
			let tail = copy(pos)
			let type = 'char'
		else
			echoerr s:Errors.InvalidArgument('Region', [a:expr] + a:000)
		endif
	else
		if t_expr is v:t_number && type(a:1) is v:t_number
			let lnum1 = a:expr
			let lnum2 = a:1
			let head = [0, lnum1, 1, 0]
			let tail = [0, lnum2, s:MAXCOL, 0]
			let type = 'line'
		elseif t_expr is v:t_list && type(a:1) is v:t_list
			let pos1 = a:expr
			let pos2 = a:1
			let type = s:str2type(get(a:000, 1, 'char'))
			if type is# 'line'
				let head = [0, pos1[1], 1, 0]
				let tail = [0, pos2[1], s:MAXCOL, 0]
			else
				let head = copy(pos1)
				let tail = copy(pos2)
			endif
		else
			echoerr s:Errors.InvalidArgument('Region', [a:expr] + a:000)
		endif
	endif
	if head == s:NULLPOS || tail == s:NULLPOS || s:inorderof(tail, head)
		echoerr s:Errors.InvalidArgument('Region', [a:expr] + a:000)
	endif

	let region = deepcopy(s:Region)
	let region.head = head
	let region.tail = tail
	let region.type = type
	if region.type is# 'block'
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
	if a:0 == 0 && type(a:expr) is v:t_dict
		let region = a:expr
		if region.head == s:NULLPOS || region.tail == s:NULLPOS
			return s:FALSE
		endif
		return s:{region.type}_is_included_in_{self.type}(region, self)
	endif

	let args = [a:expr] + a:000
	try
		let region = call('s:Region', args)
	catch /^Vim(echoerr):multiselect: Invalid argument: /
		echoerr s:Errors.InvalidArgument('Region.includes', args)
	endtry
	return self.includes(region)
endfunction "}}}

function! s:Region.isinside(expr, ...) abort  "{{{
	if a:0 == 0 && type(a:expr) is v:t_dict
		let region = a:expr
		if region.head == s:NULLPOS || region.tail == s:NULLPOS
			return s:FALSE
		endif
		return s:{self.type}_is_included_in_{region.type}(self, region)
	endif

	let args = [a:expr] + a:000
	try
		let region = call('s:Region', args)
	catch /^Vim(echoerr):multiselect: Invalid argument: /
		echoerr s:Errors.InvalidArgument('Region.isinside', args)
	endtry
	return self.isinside(region)
endfunction "}}}

function! s:Region.touches(expr, ...) abort "{{{
	if a:0 == 0 && type(a:expr) is v:t_dict
		let region = a:expr
		if region.head == s:NULLPOS || region.tail == s:NULLPOS
			return s:FALSE
		endif
		return s:{self.type}_is_touching_{region.type}(self, region)
	endif

	let args = [a:expr] + a:000
	try
		let region = call('s:Region', args)
	catch /^Vim(echoerr):multiselect: Invalid argument: /
		echoerr s:Errors.InvalidArgument('Region.touches', args)
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
lockvar! s:Region
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
	let sub = deepcopy(s:Item)
	let args = [a:expr] + a:000
	try
		let super = call('s:Region', args)
	catch /^Vim(echoerr):multiselect: Invalid argument: /
		echoerr s:Errors.InvalidArgument('Item', args)
	endtry

	let item = s:ClassSys.inherit(sub, super)
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

function! s:Item.isshownin(...) abort "{{{
	let winid = get(a:000, 0, win_getid())
	return self._highlight.status(winid) is s:Highlights.ON
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



let s:itemid = 0
function! s:itemid() abort "{{{
	let s:itemid += 1
	return s:itemid
endfunction "}}}

lockvar! s:Item
"}}}



" Change class "{{{
unlockva! s:Change
let s:Change = {
	\	'__CLASS__': 'Change',
	\	'_changelist': [],
	\	}
function! s:Change() abort "{{{
	return deepcopy(s:Change)
endfunction "}}}

function! s:Change.beforedelete(expr, ...) abort "{{{
	if a:0 == 0 && type(a:expr) is v:t_dict
		let deletion = deepcopy(a:expr)
	else
		let args = [a:expr] + a:000
		try
			let deletion = call('s:Item', args)
		catch /^Vim(echoerr):multiselect: Invalid argument: /
			echoerr s:Errors.InvalidArgument('Change.beforedelete', args)
		endtry
	endif

	if deletion.type is# 'char'
		if deletion.tail[2] == col([deletion.tail[1], '$'])
			let deletion.tail[1] += 1
			let deletion.tail[2] = 0
		endif
		call add(self._changelist, ['delete', deletion])
	elseif deletion.type is# 'line'
		let deletion.head[2] = 1
		let deletion.tail[2] = col([deletion.tail[1], '$'])
		call add(self._changelist, ['delete', deletion])
	elseif deletion.type is# 'block'
		for item in s:splitblock(deletion)
			call add(self._changelist, ['delete', item])
		endfor
	endif
	return self
endfunction "}}}

function! s:Change.afterinsert(expr, ...) abort "{{{
	if a:0 == 0 && type(a:expr) is v:t_dict
		let insertion = deepcopy(a:expr)
	else
		let args = [a:expr] + a:000
		try
			let insertion = call('s:Item', args)
		catch /^Vim(echoerr):multiselect: Invalid argument: /
			echoerr s:Errors.InvalidArgument('Change.afterinsert', args)
		endtry
	endif

	if insertion.type is# 'char'
		call add(self._changelist, ['insert', insertion])
	elseif insertion.type is# 'line'
		let insertion.head[2] = 1
		let insertion.tail[2] = col([insertion.tail[1], '$'])
		call add(self._changelist, ['insert', insertion])
	elseif insertion.type is# 'block'
		for item in s:splitblock(insertion)
			call add(self._changelist, ['insert', item])
		endfor
	endif
	return self
endfunction "}}}

function! s:Change.apply(expr) abort "{{{
	let t_expr = type(a:expr)
	if t_expr is v:t_list
		let pos = a:expr
		for [change, item] in self._changelist
			if change is# 'delete'
				call s:pull(pos, item.head, item.tail, item.type is# 'line')
			elseif change is# 'insert'
				call s:push(pos, item.head, item.tail, item.type is# 'line')
			endif
		endfor
	elseif t_expr is v:t_dict
		let region = a:expr
		call self.apply(region.head)
		call self.apply(region.tail)
	endif
	return a:expr
endfunction "}}}

function! s:Change.mapapply(itemlist) abort "{{{
	if empty(a:itemlist)
		return a:itemlist
	endif

	let t_item = type(a:itemlist[0])
	if t_item is v:t_list
		for [change, item] in self._changelist
			if change is# 'delete'
				call s:mappull(a:itemlist, item.head, item.tail, item.type is# 'line')
			elseif change is# 'insert'
				call s:mappush(a:itemlist, item.head, item.tail, item.type is# 'line')
			endif
		endfor
	elseif t_item is v:t_dict
		let itemlist = map(copy(a:itemlist), 'v:val.head')
					\+ map(copy(a:itemlist), 'v:val.tail')
		call self.mapapply(itemlist)
	endif
	return a:itemlist
endfunction "}}}



function! s:push(shiftedpos, head, tail, linewise) abort  "{{{
	if a:shiftedpos == s:NULLPOS
		return a:shiftedpos
	endif

	let shift = [0, 0, 0, 0]
	if a:linewise
		if a:shiftedpos[1] < a:head[1]
			return a:shiftedpos
		endif
		let shift[1] += a:tail[1] - a:head[1] + 1
	else
		if s:inorderof(a:shiftedpos, a:head)
			return a:shiftedpos
		endif
		if a:head[1] != a:tail[1]
			let shift[1] += a:tail[1] - a:head[1]
		endif
		if a:head[1] == a:shiftedpos[1]
			let shift[2] += a:tail[2] - a:head[2]
		endif
	endif
	let a:shiftedpos[1:2] += shift[1:2]
	return a:shiftedpos
endfunction "}}}

function! s:pull(shiftedpos, head, tail, linewise) abort "{{{
	if a:shiftedpos == s:NULLPOS
		return a:shiftedpos
	endif

	if a:linewise
		if a:shiftedpos[1] < a:head[1]
			return a:shiftedpos
		elseif a:tail[1] < a:shiftedpos[1]
			let a:shiftedpos[1] -= a:tail[1] - a:head[1] + 1
		else
			let a:shiftedpos[1] = a:head[1]
			let a:shiftedpos[2] = 1
		endif
	else
		let shift = [0, 0, 0, 0]

		" lnum
		if a:head[1] != a:tail[1] && a:shiftedpos[1] > a:head[1]
			if a:shiftedpos[1] <= a:tail[1]
				let shift[1] -= a:shiftedpos[1] - a:head[1]
			else
				let shift[1] -= a:tail[1] - a:head[1]
			endif
		endif

		" column
		if a:shiftedpos[1] <= a:tail[1] && s:inorderof(a:head, a:shiftedpos)
			if s:inorderof(a:tail, a:shiftedpos)
				if a:head[1] == a:shiftedpos[1]
					let shift[2] -= a:tail[2] - a:head[2] + 1
				else
					let shift[2] -= a:tail[2]
				endif
			else
				let shift[2] -= a:shiftedpos[2] - a:head[2]
			endif
		endif
		let a:shiftedpos[1:2] += shift[1:2]
	endif
	return a:shiftedpos
endfunction "}}}

function! s:mappush(poslist, head, tail, linewise) abort "{{{
	if a:linewise
		let poslist = filter(copy(a:poslist), 'v:val[1] >= a:head[1]')
		let shift = [0, a:tail[1] - a:head[1] + 1, 0, 0]
		call map(poslist, 's:shift(v:val, shift)')
	else
		let poslist0 = filter(copy(a:poslist), '!s:inorderof(v:val, a:head)')
		let poslist1 = filter(copy(poslist0), 'a:head[1] == v:val[1]')

		let shift = [0, 0, a:tail[2] - a:head[2], 0]
		call map(poslist1, 's:shift(v:val, shift)')

		if a:head[1] != a:tail[1]
			let shift = [0, a:tail[1] - a:head[1], 0, 0]
			call map(poslist0, 's:shift(v:val, shift)')
		endif
	endif
	return a:poslist
endfunction "}}}

function! s:mappull(poslist, head, tail, linewise) abort "{{{
	if a:linewise
		let poslist0 = filter(copy(a:poslist), 'a:tail[1] < v:val[1]')
		let poslist1 = filter(copy(a:poslist), 'a:head[1] <= v:val[1] && v:val[1] <= a:tail[1]')

		let shift = [0, -a:tail[1] + a:head[1] - 1, 0, 0]
		call map(poslist0, 's:shift(v:val, shift)')

		let set = [0, a:head[1], 1, 0]
		call map(poslist1, 's:setpos(v:val, set)')
	else
		let poslist0 = filter(copy(a:poslist), 'v:val[1] <= a:tail[1] && s:inorderof(a:head, v:val)')
		let poslist1 = filter(copy(poslist0), 's:inorderof(a:tail, v:val)')
		let poslist2 = filter(copy(poslist1), 'a:head[1] == v:val[1]')
		let poslist3 = filter(copy(poslist1), 'a:head[1] != v:val[1]')
		let poslist4 = filter(copy(poslist0), '!s:inorderof(a:tail, v:val)')

		" col
		let shift = [0, 0, a:head[2] - a:tail[2] - 1, 0]
		call map(poslist2, 's:shift(v:val, shift)')

		let shift = [0, 0, -a:tail[2], 0]
		call map(poslist3, 's:shift(v:val, shift)')

		call map(poslist4, 's:setcol(v:val, a:head[2])')

		" lnum
		if a:head[1] != a:tail[1]
			let poslist5 = filter(copy(a:poslist), 'v:val[1] > a:head[1]')
			let poslist6 = filter(copy(poslist5), 'v:val[1] <= a:tail[1]')
			let poslist7 = filter(copy(poslist5), 'v:val[1] > a:tail[1]')

			call map(poslist6, 's:setlnum(v:val, a:head[1])')

			let shift = [0, a:head[1] - a:tail[1], 0, 0]
			call map(poslist7, 's:shift(v:val, shift)')
		endif
	endif
	return a:poslist
endfunction "}}}

function! s:shift(pos, shift) abort "{{{
	let a:pos[1:2] += a:shift[1:2]
	return a:pos
endfunction "}}}

function! s:setpos(pos, set) abort "{{{
	let a:pos[1:2] = a:set[1:2]
	return a:pos
endfunction "}}}

function! s:setcol(pos, col) abort "{{{
	let a:pos[2] = a:col
	return a:pos
endfunction "}}}

function! s:setlnum(pos, lnum) abort "{{{
	let a:pos[1] = a:lnum
	return a:pos
endfunction "}}}

function! s:splitblock(item) abort "{{{
	let view = winsaveview()
	let dispheadcol = virtcol(a:item.head[1:2])
	let disptailcol = virtcol(a:item.tail[1:2])
	let virtualedit = &virtualedit
	let &virtualedit = 'onemore'
	try
		let itemlist = []
		if a:item.extended
			for lnum in range(a:item.head[1], a:item.tail[1])
				if empty(getline(lnum))
					continue
				endif
				execute printf('normal! %sG%s|', lnum, dispheadcol)
				let head = getpos('.')
				normal! $
				let tail = getpos('.')
				if virtcol(tail[1:2]) < dispheadcol
					continue
				endif
				let itemlist += [s:Item(head, tail, 'v')]
			endfor
		else
			for lnum in range(a:item.head[1], a:item.tail[1])
				if empty(getline(lnum))
					continue
				endif
				execute printf('normal! %sG%s|', lnum, dispheadcol)
				let head = getpos('.')
				execute printf('normal! %s|', disptailcol)
				let tail = getpos('.')
				if virtcol(tail[1:2]) < dispheadcol
					continue
				endif
				let itemlist += [s:Item(head, tail, 'v')]
			endfor
		endif
	finally
		let &virtualedit = virtualedit
		call winrestview(view)
	endtry
	return itemlist
endfunction "}}}
lockvar! s:Change
"}}}



function! s:str2type(str) abort "{{{
	if a:str is# 'line' || a:str is# 'V'
		return 'line'
	elseif a:str is# 'block' || a:str[0] is# "\<C-v>"
		return 'block'
	endif
	return 'char'
endfunction "}}}

function! s:str2visualcmd(str) abort "{{{
	if a:str is# 'line' || a:str is# 'V'
		return 'V'
	elseif a:str is# 'block' || a:str[0] is# "\<C-v>"
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

function! s:isextended() abort "{{{
	if visualmode() isnot# "\<C-v>"
		return s:FALSE
	endif

	let view = winsaveview()
	normal! gv
	let extended = winsaveview().curswant == s:MAXCOL
	execute "normal! \<Esc>"
	call winrestview(view)
	return extended
endfunction
"}}}

function! s:searchpos(pat, ...) abort "{{{
	return [0] + call('searchpos', [a:pat] + a:000) + [0]
endfunction "}}}

function! s:openfold(lnum) abort "{{{
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



" Buffer module {{{
unlockvar! s:Buffer
let s:Buffer = {
	\	'__MODULE__': 'Buffer',
	\	'Region': function('s:Region'),
	\	'Item': function('s:Item'),
	\	'Change': function('s:Change'),
	\	'str2type': function('s:str2type'),
	\	'str2visualcmd': function('s:str2visualcmd'),
	\	'inorderof': function('s:inorderof'),
	\	'inbetween': function('s:inbetween'),
	\	'isextended': function('s:isextended'),
	\	'searchpos': function('s:searchpos'),
	\	'openfold': function('s:openfold'),
	\	'patternofselection': function('s:patternofselection'),
	\	}
lockvar! s:Buffer
"}}}

function! multiselect#Buffer#_import() abort "{{{
	return s:Buffer
endfunction "}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
