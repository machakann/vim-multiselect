function! multiselect#ClassSys#_import() abort "{{{
	return s:ClassSys
endfunction "}}}

function! s:inherit(sub, super) abort "{{{
	call extend(a:sub, a:super, 'keep')
	let a:sub.__SUPER__ = {}
	for [key, l:Val] in items(a:super)
		if type(l:Val) == v:t_func || key ==# '__SUPER__'
			let a:sub.__SUPER__[key] = l:Val
		endif
	endfor
	return a:sub
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

" ClassSys module {{{
let s:ClassSys = {
	\	'__MODULE__': 'ClassSys',
	\	'inherit': function('s:inherit'),
	\	'super': function('s:super'),
	\	}
"}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
