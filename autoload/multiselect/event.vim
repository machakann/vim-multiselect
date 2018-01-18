function! multiselect#event#_import() abort "{{{
	return s:Events
endfunction "}}}

" Event class{{{
unlockvar! s:Event
let s:ON = 1
let s:OFF = 0
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
lockvar! s:Event
"}}}
" Events module {{{
unlockvar! s:Events
let s:Events = {
	\	'__MODULE__': 'Events',
	\	'Event': function('s:Event'),
	\	'ON': s:ON,
	\	'OFF': s:OFF,
	\	}
lockvar! s:Events
"}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
