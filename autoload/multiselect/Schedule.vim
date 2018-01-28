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
function! s:Switch._on() abort "{{{
	let self.__switch__.state = s:ON
	let self.__switch__.skipcount = -1
	return self
endfunction "}}}
function! s:Switch._off() abort "{{{
	let self.__switch__.state = s:OFF
	let self.__switch__.skipcount = -1
	return self
endfunction "}}}
function! s:Switch.skip(...) abort "{{{
	let n = get(a:000, 0, 1)
	if n <= 0
		return self
	endif
	call self._off()
	let self.__switch__.skipcount = n
	return self
endfunction "}}}
function! s:Switch._isactive() abort "{{{
	return self.__switch__.state
endfunction "}}}
function! s:Switch._skipsthistime() abort "{{{
	if self._isactive()
		return s:FALSE
	endif
	if self.__switch__.skipcount > 0
		let self.__switch__.skipcount -= 1
		if self.__switch__.skipcount == 0
			call self._on()
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
" TimerTask class (inherits Switch, Counter and Task classes) {{{
unlockvar! s:TimerTask
let s:TimerTask = {
	\	'__CLASS__': 'TimerTask',
	\	'_id': -1,
	\	'_state': s:OFF,
	\	}
function! s:TimerTask() abort "{{{
	let switch = s:Switch()
	let counter = s:Counter(1)
	let task = s:Task()
	let timertask = deepcopy(s:TimerTask)
	return s:ClassSys.inherit(timertask, task, counter, switch)
endfunction "}}}
function! s:TimerTask.trigger(...) abort "{{{
	if self._skipsthistime()
		return self
	endif
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
	let clone.__switch__ = deepcopy(self.__switch__)
	let clone.__counter__ = deepcopy(self.__counter__)
	let clone.__timer__.id = -1
	let clone._state = s:OFF
	let clone._orderlist = copy(self._orderlist)
	return clone
endfunction "}}}
function! s:TimerTask.start(time) abort "{{{
	call self.stop()
	call self.repeat()
	if self.leftcount() == 0
		return self
	endif

	let id = timer_start(a:time, function('s:timercall'), {'repeat': -1})
	let self._id = id
	let s:timertable[string(id)] = self
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
function! s:TimerTask.isactive() abort "{{{
	return self._state && s:ClassSys.super(self, 'Switch')._isactive()
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
	\	'_name': '',
	\	'_state': s:OFF,
	\	}
function! s:EventTask() abort "{{{
	let switch = s:Switch()
	let counter = s:Counter(-1)
	let task = s:Task()
	let eventtask = deepcopy(s:EventTask)
	return s:ClassSys.inherit(eventtask, task, counter, switch)
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
	if self.hasdone()
		call self.stop()
	endif
	return self
endfunction "}}}
function! s:EventTask.clone() abort "{{{
	let clone = s:EventTask()
	let clone.__switch__ = deepcopy(self.__switch__)
	let clone.__counter__ = deepcopy(self.__counter__)
	let clone._name = ''
	let clone._state = s:OFF
	let clone._orderlist = copy(self._orderlist)
	return clone
endfunction "}}}
function! s:EventTask.start(name) abort "{{{
	let self._name = a:name
	call self.stop()
	if self.leftcount() == 0
		return self
	endif

	if !has_key(s:eventtable, a:name)
		let s:eventtable[a:name] = []
		augroup multiselect
			if count(s:BUILTINEVENTS, a:name) != 0
				" Built-in autocmd
				execute printf('autocmd %s * call s:doautocmd("%s")',
								\ a:name, a:name)
			else
				" User autocmd
				execute printf('autocmd User %s call s:doautocmd("%s")',
								\ a:name, a:name)
			endif
		augroup END
	endif
	call add(s:eventtable[a:name], self)
	let self._state = s:ON
	return self
endfunction "}}}
function! s:EventTask.stop() abort "{{{
	if has_key(s:eventtable, self._name)
		call filter(s:eventtable[self._name], 'v:val isnot self')
	endif
	call s:sweep(self._name)
	let self._state = s:OFF
	return self
endfunction "}}}
function! s:EventTask.isactive() abort "{{{
	return self._state && s:ClassSys.super(self, 'Switch')._isactive()
endfunction "}}}
function! s:doautocmd(name) abort "{{{
	for event in s:eventtable[a:name]
		call event.trigger()
	endfor
	call s:sweep(a:name)
endfunction "}}}
function! s:sweep(name) abort "{{{
	if !has_key(s:eventtable, a:name)
		return
	endif
	call filter(s:eventtable[a:name], '!v:val.hasdone()')
	if empty(s:eventtable[a:name])
		augroup multiselect
			execute printf('autocmd! %s *', a:name)
		augroup END
		call remove(s:eventtable, a:name)
	endif
endfunction "}}}
lockvar! s:EventTask
"}}}
" EitherTask class (inherits Switch, Counter and Task classes) {{{
let s:EitherTask = {
	\	'__CLASS__': 'EitherTask',
	\	'__eithertask__': {
	\		'Event': {},
	\		'Timer': [],
	\		},
	\	'_state': s:OFF,
	\	}
function! s:EitherTask() abort "{{{
	let switch = s:Switch()
	let counter = s:Counter(1)
	let task = s:Task()
	let eithertask = deepcopy(s:EitherTask)
	return s:ClassSys.inherit(eithertask, task, counter, switch)
endfunction "}}}
function! s:EitherTask.event(name) abort "{{{
	if has_key(self.__eithertask__.Event, a:name)
		return self
	endif
	let event = s:EventTask()
	call event.call(self.trigger, [], self).repeat(-1)
	let self.__eithertask__.Event[a:name] = event
	return self
endfunction "}}}
function! s:EitherTask.timer(time) abort "{{{
	if !empty(self.__eithertask__.Timer)
		let self.__eithertask__.Timer[0] = a:time
		return self
	endif
	let timer = s:TimerTask()
	call timer.call(self.trigger, [], self).repeat(-1)
	let self.__eithertask__.Timer = [a:time, timer]
	return self
endfunction "}}}
function! s:EitherTask.trigger(...) abort "{{{
	if self._skipsthistime()
		return self
	endif
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
function! s:EitherTask.start() abort "{{{
	if !empty(self.__eithertask__.Event)
		for [name, task] in items(self.__eithertask__.Event)
			call task.start(name)
		endfor
	endif
	if !empty(self.__eithertask__.Timer)
		let [time, task] = self.__eithertask__.Timer
		call task.start(time)
	endif
	return self
endfunction "}}}
function! s:EitherTask.stop() abort "{{{
	if !empty(self.__eithertask__.Event)
		for [name, event] in items(self.__eithertask__.Event)
			call event.stop()
			call remove(self.__eithertask__.Event, name)
		endfor
	endif
	if !empty(self.__eithertask__.Timer)
		let [_, timer] = self.__eithertask__.Timer
		call timer.stop()
		call filter(self.__eithertask__.Timer, 0)
	endif
	return self
endfunction "}}}
function! s:EitherTask.isactive() abort "{{{
	return self._state && s:ClassSys.super(self, 'Switch')._isactive()
endfunction "}}}
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
	\	'EitherTask': function('s:EitherTask'),
	\	}
lockvar! s:Schedule
"}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
