let s:Multiselect = multiselect#import()
let s:multiselector = s:Multiselect.load()
let s:MAXCOL = 2147483647
let s:NULLPOS = [0, 0, 0, 0]

let s:inorderof = s:Multiselect.inorderof

function! multiselect#keymap#check(mode) abort  "{{{
	let head = getpos("'<")
	let tail = getpos("'>")
	let type = visualmode()[0]
	let extended = type ==# "\<C-v>" ? s:is_extended() : 0
	call s:multiselector.check(head, tail, type, extended)
endfunction "}}}
function! multiselect#keymap#checksearched(mode) abort "{{{
	if empty(@/)
		return
	endif

	let view = winsaveview()
	let lastpattern = @/
	if a:mode ==# 'x'
		let start = getpos("'<")
		let end = getpos("'>")
	else
		let start = [0, 1, 1, 0]
		let end = [0, line('$'), col([line('$'), '$']), 0]
	endif
	let Region = s:Multiselect.Region(start, end)
	call setpos('.', Region.head)

	let head = s:searchpos(lastpattern, 'cW')
	if head == s:NULLPOS || !Region.includes(head)
		call winrestview(view)
		return
	endif
	while 1
		let tail = s:searchpos(lastpattern, 'ceW')
		if !Region.includes(tail)
			break
		endif
		call s:multiselector.check(head, tail, 'v')
		let head = s:searchpos(lastpattern, 'W')
		if head == s:NULLPOS || !Region.includes(head)
			break
		endif
	endwhile
	call winrestview(view)
endfunction "}}}
function! multiselect#keymap#uncheck(mode) abort  "{{{
	if a:mode ==# 'n'
		call s:multiselector.uncheck()
	elseif a:mode ==# 'x'
		call s:multiselector.uncheck(getpos("'<"), getpos("'>"))
	endif
endfunction "}}}
function! multiselect#keymap#uncheckall(mode) abort  "{{{
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
function! s:searchpos(pat, flag) abort "{{{
	return [0] + searchpos(a:pat, a:flag) + [0]
endfunction "}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
