" highlight object - managing highlight on a buffer
let s:TRUE = 1
let s:FALSE = 0
let s:ON = s:TRUE
let s:OFF = s:FALSE
let s:NULLPOS = [0, 0, 0, 0]

function! multiselect#highlight#import() abort  "{{{
	return s:HighlightModule
endfunction "}}}

" id class{{{
let s:Id = {
	\	'__CLASS__': 'Id',
	\	'id': -1,
	\	'winid': -1,
	\	}
function! s:Id(id, winid) abort "{{{
	let id = deepcopy(s:Id)
	let id.id = a:id
	let id.winid = a:winid
	return id
endfunction "}}}
"}}}
" Highlight class{{{
unlockvar! s:Highlight
let s:Highlight = {
	\	'__CLASS__': 'Highlight',
	\	'group': '',
	\	'region': {
	\		'head': deepcopy(s:NULLPOS),
	\		'tail': deepcopy(s:NULLPOS),
	\		},
	\	'orderlist': [],
	\	'idlist': [],
	\	}
function! s:Highlight() abort "{{{
	return deepcopy(s:Highlight)
endfunction "}}}
function! s:Highlight.initialize(hi_group, region) abort "{{{
	if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS ||
	\		s:inorderof(a:region.tail, a:region.head)
		return s:FALSE
	endif

	let initialized = s:FALSE
	if self.group != a:hi_group
		let self.group = a:hi_group
		let initialized = s:TRUE
	endif

	if self.region.head != a:region.head || self.region.tail != a:region.tail
		let self.orderlist = s:highlight_order(a:region)
		let self.region.head = copy(a:region.head)
		let self.region.tail = copy(a:region.tail)
		let initialized = s:TRUE
	endif
	return initialized
endfunction "}}}
function! s:Highlight.show() dict abort "{{{
	if empty(self.orderlist)
		return
	endif

	if s:in_cmdline_window()
		call self.showlocal()
	else
		let original_winid = win_getid()
		for winid in win_findbuf(bufnr('%'))
			if self.status(winid) is s:OFF
				noautocmd call win_gotoid(winid)
				call self.showlocal()
			endif
		endfor
		noautocmd call win_gotoid(original_winid)
	endif
	call filter(self.idlist, 'v:val.id > 0')
endfunction "}}}
function! s:Highlight.showlocal() abort "{{{
	let winid = win_getid()
	if self.status(winid) is s:ON
		return
	endif

	let idlist = []
	for orderset in self.orderlist
		let newid = matchaddpos(self.group, orderset)
		call add(idlist, newid)
	endfor
	call map(idlist, 's:Id(v:val, winid)')
	call extend(self.idlist, idlist)
endfunction "}}}
function! s:Highlight.quench() dict abort "{{{
	if empty(self.idlist)
		return
	endif

	if s:in_cmdline_window()
		call self.quenchlocal()
	else
		let original_winid = win_getid()
		for winid in win_findbuf(bufnr('%'))
			if self.status(winid)
				noautocmd call win_gotoid(winid)
				call self.quenchlocal()
			endif
		endfor
		noautocmd call win_gotoid(original_winid)
	endif
endfunction "}}}
function! s:Highlight.quenchlocal() abort "{{{
	let winid = win_getid()
	for id in self.idlist
		if id.winid == winid
			call matchdelete(id.id)
			let id.id = -1
		endif
	endfor
	call filter(self.idlist, 'v:val.id > -1')
endfunction "}}}
function! s:Highlight.status(winid) abort "{{{
	if !empty(filter(copy(self.idlist), 'v:val.winid == a:winid'))
		return s:ON
	endif
	return s:OFF
endfunction "}}}
lockvar! s:Highlight

function! s:highlight_order(item) abort "{{{
	if a:item.type ==# 'char'
		let orderlist = s:highlight_order_charwise(a:item)
	elseif a:item.type ==# 'line'
		let orderlist = s:highlight_order_linewise(a:item)
	elseif a:item.type ==# 'block'
		let orderlist = s:highlight_order_blockwise(a:item)
	else
		return []
	endif
	return s:eight_order_per_each(orderlist)
endfunction "}}}
function! s:highlight_order_charwise(region) abort "{{{
	if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS || s:inorderof(a:region.tail, a:region.head)
		return []
	endif

	let orderlist = []
	if a:region.head[1] == a:region.tail[1]
		let orderlist += [a:region.head[1:2] + [a:region.tail[2] - a:region.head[2] + 1]]
	else
		for lnum in range(a:region.head[1], a:region.tail[1])
			if lnum == a:region.head[1]
				let orderlist += [a:region.head[1:2] + [col([a:region.head[1], '$']) - a:region.head[2] + 1]]
			elseif lnum == a:region.tail[1]
				let orderlist += [[a:region.tail[1], 1] + [a:region.tail[2]]]
			else
				let orderlist += [[lnum]]
			endif
		endfor
	endif
	return orderlist
endfunction "}}}
function! s:highlight_order_linewise(region) abort "{{{
	if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS || a:region.head[1] > a:region.tail[1]
		return []
	endif
	return map(range(a:region.head[1], a:region.tail[1]), '[v:val]')
endfunction "}}}
function! s:highlight_order_blockwise(region) abort "{{{
	if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS || s:inorderof(a:region.tail, a:region.head)
		return []
	endif

	let view = winsaveview()
	let vcol_head = virtcol(a:region.head[1:2])
	let vcol_tail = virtcol(a:region.tail[1:2])
	let orderlist = []
	for lnum in range(a:region.head[1], a:region.tail[1])
		call cursor(lnum, 1)
		execute printf('normal! %s|', vcol_head)
		let head = getpos('.')
		execute printf('normal! %s|', vcol_tail)
		let tail = getpos('.')
		let col = head[2]
		let len = tail[2] - head[2] + 1
		let orderlist += [[lnum, col, len]]
	endfor
	call winrestview(view)
	return orderlist
endfunction "}}}
function! s:inorderof(pos1, pos2) abort  "{{{
	return a:pos1[1] < a:pos2[1] || (a:pos1[1] == a:pos2[1] && a:pos1[2] < a:pos2[2])
endfunction "}}}
function! s:eight_order_per_each(orderlist) abort "{{{
  if empty(a:orderlist)
    return []
  endif

  let n = 0
  let orderset = []
  let newlist = []
  for order in a:orderlist
    call add(orderset, order)
    let n += 1
    if n == 8
      call add(newlist, orderset)
      let orderset = []
      let n = 0
    endif
  endfor
  if !empty(orderset)
    call add(newlist, orderset)
  endif
  return newlist
endfunction "}}}
function! s:in_cmdline_window() abort "{{{
	return getcmdwintype() !=# ''
endfunction "}}}
"}}}
" Highlight module{{{
unlockvar! s:HighlightModule
let s:HighlightModule = {
	\	'__MODULE__': 'Highlight',
	\	'ON': s:ON,
	\	'OFF': s:OFF,
	\	'Highlight': function('s:Highlight'),
	\	}
lockvar! s:HighlightModule
"}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
