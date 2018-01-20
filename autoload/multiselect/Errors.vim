function! multiselect#Errors#_import() abort "{{{
	return s:Errors
endfunction "}}}

function! s:InvalidArgument(name, args) abort "{{{
	let argstr = join(map(copy(a:args), 'string(v:val)'), ', ')
	let argstr = s:trimLR(argstr)
	return printf('multiselect: Invalid argument: %s(%s)', a:name, argstr)
endfunction "}}}
function! s:trimLR(str) abort "{{{
	if strlen(a:str) <= 30
		return a:str
	endif
	return a:str[:19] . ' ... ' a:str[-5:-1]
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
