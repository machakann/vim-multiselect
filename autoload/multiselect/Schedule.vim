" TODO: Implement ChainedTask
" TODO: Implement EventChain
let s:ClassSys = multiselect#ClassSys#_import()
let s:Errors = multiselect#Errors#_import()
let s:TRUE = 1
let s:FALSE = 0
let s:ON = 1
let s:OFF = 0
let s:BUILTINEVENTS = getcompletion('', 'event')

let s:timertable = {}
let s:eventtable = {}
augroup multiselect
	autocmd!
augroup END

function! multiselect#Schedule#_import() abort "{{{
	return s:Schedule
endfunction "}}}

" Switch class {{{
unlockvar! s:Switch
let s:Switch = {
	\	'__CLASS__': 'Switch',
	\	'__switch__': {
	\		'state': s:ON,
	\		'skipcount': -1,
	\		}
	\	}
function! s:Switch() abort "{{{
	return deepcopy(s:Switch)
endfunction "}}}
function! s:Switch.on() abort "{{{
	let self.__switch__.state = s:ON
	let self.__switch__.skipcount = -1
	return self
endfunction "}}}
function! s:Switch.off() abort "{{{
	let self.__switch__.state = s:OFF
	let self.__switch__.skipcount = -1
	return self
endfunction "}}}
function! s:Switch.skip(...) abort "{{{
	let n = get(a:000, 0, 1)
	if n <= 0
		return self
	endif
	call self.off()
	let self.__switch__.skipcount = n
	return self
endfunction "}}}
function! s:Switch.isactive() abort "{{{
	return self.__switch__.state
endfunction "}}}
function! s:Switch._skipsthistime() abort "{{{
	if self.isactive()
		return s:FALSE
	endif
	if self.__switch__.skipcount > 0
		let self.__switch__.skipcount -= 1
		if self.__switch__.skipcount == 0
			call self.on()
		endif
	endif
	return s:TRUE
endfunction "}}}
lockvar! s:Switch
"}}}
" Counter class {{{
unlockvar! s:Counter
let s:Counter = {
	\	'__CLASS__': 'Counter',
	\	'__counter__': {
	\		'repeat': 1,
	\		'done': 0,
	\		}
	\	}
function! s:Counter(count) abort "{{{
	let counter = deepcopy(s:Counter)
	let counter.__counter__.repeat = a:count
	return counter
endfunction "}}}
function! s:Counter.repeat(...) abort "{{{
	if a:0 > 0
		let self.__counter__.repeat = a:1
	endif
	let self.__counter__.done = 0
	return self
endfunction "}}}
function! s:Counter._tick(...) abort "{{{
	let self.__counter__.done += get(a:000, 0, 1)
endfunction "}}}
function! s:Counter.leftcount() abort "{{{
	if self.__counter__.repeat < 0
		return -1
	endif
	return max([self.__counter__.repeat - self.__counter__.done, 0])
endfunction "}}}
function! s:Counter.hasdone() abort "{{{
	if self.__counter__.repeat == 0
		return s:TRUE
	elseif self.__counter__.repeat < 0
		return s:FALSE
	endif
	return self.leftcount() == 0
endfunction "}}}
function! s:Counter._finish() abort "{{{
	let left = self.leftcount()
	if left < 0
		call self.repeat(0)
	else
		call self._tick(left)
	endif
	return self
endfunction "}}}
lockvar! s:Counter
"}}}
" Task class {{{
unlockvar! s:Task
let s:Task = {
	\	'__CLASS__': 'Task',
	\	'_orderlist': [],
	\	}
function! s:Task() abort "{{{
	return deepcopy(s:Task)
endfunction "}}}
function! s:Task.trigger() abort "{{{
	for [kind, expr] in self._orderlist
		if kind is# 'call'
			call call('call', expr)
		elseif kind is# 'execute'
			execute expr
		elseif kind is# 'task'
			call expr.trigger()
		endif
	endfor
	return self
endfunction "}}}
function! s:Task.call(func, args, ...) abort "{{{
	let order = ['call', [a:func, a:args] + a:000]
	call add(self._orderlist, order)
	return self
endfunction "}}}
function! s:Task.execute(cmd) abort "{{{
	let order = ['execute', a:cmd]
	call add(self._orderlist, order)
	return self
endfunction "}}}
function! s:Task.append(task) abort "{{{
	let order = ['task', a:task]
	call add(self._orderlist, order)
	return self
endfunction "}}}
function! s:Task.clear() abort "{{{
	call filter(self._orderlist, 0)
	return self
endfunction "}}}
function! s:Task.clone() abort "{{{
	let clone = s:Task()
	let clone._orderlist = copy(self._orderlist)
	return clone
endfunction "}}}
lockvar! s:Task
"}}}
" TimerTask class (inherits Counter and Task classes) {{{
unlockvar! s:TimerTask
let s:TimerTask = {
	\	'__CLASS__': 'TimerTask',
	\	'_id': -1,
	\	}
function! s:TimerTask() abort "{{{
	let counter = s:Counter(1)
	let task = s:Task()
	let timertask = deepcopy(s:TimerTask)
	let super = s:ClassSys.inherit(task, counter)
	return s:ClassSys.inherit(timertask, super)
endfunction "}}}
function! s:TimerTask.trigger(...) abort "{{{
	let forcibly = get(a:000, 0, s:FALSE)
	if !forcibly && self.hasdone()
		return self
	endif
	call s:ClassSys.super(self, 'Task').trigger()
	call self._tick()
	if self.hasdone()
		call self.stop()
	endif
	return self
endfunction "}}}
function! s:TimerTask.clone() abort "{{{
	let clone = s:TimerTask()
	let clone.__counter__ = deepcopy(self.__counter__)
	let clone.__timer__.id = -1
	let clone._orderlist = copy(self._orderlist)
	return clone
endfunction "}}}
function! s:TimerTask.start(time, ...) abort "{{{
	let options = get(a:000, 0, {})
	if !has_key(options, 'repeat')
		let options.repeat = self.leftcount()
	endif
	call self.stop()
	let id = timer_start(a:time, function('s:timercall'), options)
	let self._id = id
	let s:timertable[string(id)] = self
	call self.repeat(options.repeat)
	return self
endfunction "}}}
function! s:TimerTask.stop() abort "{{{
	if self._id < 0
		return self
	endif
	let idstr = string(self._id)
	if has_key(s:timertable, idstr)
		call remove(s:timertable, idstr)
	endif
	if !empty(timer_info(self._id))
		call timer_stop(self._id)
		let self._id = -1
	endif
	return self
endfunction "}}}
function! s:timercall(id) abort "{{{
	if !has_key(s:timertable, string(a:id))
		return
	endif
	let timertask = s:timertable[string(a:id)]
	call timertask.trigger()
endfunction "}}}
lockvar! s:TimerTask
"}}}
" EventTask class (inherits Switch, Counter and Task classes) {{{
unlockvar! s:EventTask
let s:EventTask = {
	\	'__CLASS__': 'EventTask',
	\	'name': '',
	\	}
function! s:EventTask(name) abort "{{{
	let switch = s:Switch()
	let counter = s:Counter(-1)
	let task = s:Task()
	let eventtask = deepcopy(s:EventTask)
	let super = s:ClassSys.inherit(counter, switch)
	let super = s:ClassSys.inherit(task, super)
	let eventtask = s:ClassSys.inherit(eventtask, super)
	let eventtask.name = a:name
	if count(s:BUILTINEVENTS, a:name) != 0
		" Built-in autocmd
		if !has_key(s:eventtable, a:name)
			let s:eventtable[a:name] = []
			augroup multiselect
				execute printf('autocmd %s * call s:doautocmd("%s")', a:name, a:name)
			augroup END
		endif
		call add(s:eventtable[a:name], eventtask)
	else
		" User autocmd
		call eventtask.call(function('s:douserautocmd'), [a:name])
	endif
	return eventtask
endfunction "}}}
function! s:EventTask.trigger(...) abort "{{{
	if self._skipsthistime()
		return self
	endif
	let forcibly = get(a:000, 0, s:FALSE)
	if !forcibly && self.hasdone()
		return self
	endif
	call s:ClassSys.super(self, 'Task').trigger()
	call self._tick()
	return self
endfunction "}}}
function! s:EventTask.clone() abort "{{{
	let clone = s:EventTask(self.name)
	let clone.__switch__ = deepcopy(self.__switch__)
	let clone.__counter__ = deepcopy(self.__counter__)
	let clone._orderlist = copy(self._orderlist)
	return clone
endfunction "}}}
function! s:EventTask.finish() abort "{{{
	return self._finish()
	if has_key(s:eventtable, self.name)
		call filter(s:eventtable[self.name], 'v:val isnot self')
	endif
	return self
endfunction "}}}
function! s:doautocmd(name) abort "{{{
	for event in s:eventtable[a:name]
		call event.trigger()
	endfor
	call filter(s:eventtable[a:name], '!v:val.hasdone()')

	if empty(s:eventtable[a:name])
		augroup multiselect
			execute printf('autocmd! %s *', a:name)
		augroup END
		call remove(s:eventtable, a:name)
	endif
endfunction "}}}
function! s:douserautocmd(name) abort "{{{
	if !exists('#User#' . a:name)
		return
	endif
	execute 'doautocmd <nomodeline> User ' . a:name
endfunction "}}}
lockvar! s:EventTask
"}}}

" Schedule module {{{
unlockvar! s:Schedule
let s:Schedule = {
	\	'__MODULE__': 'Schedule',
	\	'Switch': function('s:Switch'),
	\	'Counter': function('s:Counter'),
	\	'Task': function('s:Task'),
	\	'TimerTask': function('s:TimerTask'),
	\	'EventTask': function('s:EventTask'),
	\	}
lockvar! s:Schedule
"}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
