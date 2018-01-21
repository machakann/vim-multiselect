function! multiselect#Errors#_import() abort "{{{
	return s:Errors
endfunction "}}}

function! s:InvalidArgument(name, args) abort "{{{
	let template = 'multiselect: Invalid argument: %s(%s)'
	let len = (&columns - 5) - (strlen(template) + 4) - strlen(a:name)
	let argstr = join(map(copy(a:args), 'string(v:val)'), ', ')
	return printf(template, a:name, s:trimmiddle(argstr, len))
endfunction "}}}
function! s:trimmiddle(str, len) abort "{{{
	if strlen(a:str) <= a:len
		return a:str
	endif
	let len = a:len - 10
	return a:str[: len - 1] . ' ... ' . a:str[-5:-1]
endfunction "}}}

" Errors module {{{
let s:Errors = {
	\	'__MODULE__': 'Errors',
	\	'InvalidArgument': function('s:InvalidArgument'),
	\	}
"}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
