function! multiselect#Errors#_import() abort "{{{
	return s:Errors
endfunction "}}}

function! s:InvalidArgument(name) abort "{{{
	return printf('multiselect: Invalid argument for %s()', a:name)
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
