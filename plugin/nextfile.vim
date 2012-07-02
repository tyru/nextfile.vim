" vim:foldmethod=marker:fen:
scriptencoding utf-8

" INCLUDE GUARD {{{
if exists('g:loaded_nextfile') && g:loaded_nextfile != 0 | finish | endif
let g:loaded_nextfile = 1
" }}}
" SAVING CPO {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}

" GLOBAL VARIABLES {{{
if ! exists('g:nf_map_next')
    let g:nf_map_next = '<Leader>n'
endif
if ! exists('g:nf_map_previous')
    let g:nf_map_previous = '<Leader>p'
endif
if ! exists('g:nf_include_dotfiles')
    let g:nf_include_dotfiles = 0
endif
if ! exists('g:nf_open_command')
    let g:nf_open_command = 'edit'
endif
if ! exists('g:nf_loop_files')
    let g:nf_loop_files = 0
endif
if ! exists('g:nf_ignore_dir')
    let g:nf_ignore_dir = 1
endif
if ! exists('g:nf_ignore_ext') || type(g:nf_ignore_ext) != type([])
    let g:nf_ignore_ext = []
endif
if ! exists('g:nf_disable_if_empty_name')
    let g:nf_disable_if_empty_name = 0
endif
if ! exists('g:nf_sort_funcref')
    let g:nf_sort_funcref = '<SID>sort_compare'
endif

let s:commands = {
\   'NFLoadGlob' : 'NFLoadGlob',
\ }
if ! exists('g:nf_commands')
    let g:nf_commands = s:commands
else
    call extend(g:nf_commands, s:commands, 'keep')
endif
unlet s:commands
" }}}


" FUNCTION DEFINITION {{{

" UTIL FUNCTION {{{
" s:warn {{{
func! s:warn(msg)
    echohl WarningMsg
    echomsg a:msg
    echohl None
endfunc
" }}}
" s:warnf {{{
func! s:warnf(fmt, ...)
    call s:warn(call('printf', [a:fmt] + a:000))
endfunc
" }}}
" s:get_idx_of_list {{{
func! s:get_idx_of_list(lis, elem)
    let i = 0
    while i < len(a:lis)
        if a:lis[i] ==# a:elem
            return i
        endif
        let i = i + 1
    endwhile
    throw "not found"
endfunc
" }}}
" s:glob_list {{{
func! s:glob_list(expr)
    let files = split(glob(a:expr), '\n')
    " get rid of '.' and '..'
    call filter(files, 'fnamemodify(v:val, ":t") !=# "." && fnamemodify(v:val, ":t") !=# ".."')
    return files
endfunc
" }}}
" s:sort_compare {{{
func! s:sort_compare(a, b)
    let [a, b] = [string(a:a), string(a:b)]
    return a ==# b ? 0 : a > b ? 1 : -1
endfunc
" }}}
" }}}


" s:get_files_list {{{
func! s:get_files_list(...)
    let glob_expr = a:0 == 0 ? '*' : a:1
    " get files list
    let files = s:glob_list(expand('%:p:h') . '/' . glob_expr)
    if g:nf_include_dotfiles
        let files += s:glob_list(expand('%:p:h') . '/.*')
    endif
    if g:nf_ignore_dir
        call filter(files, '! isdirectory(v:val)')
    endif
    for ext in g:nf_ignore_ext
        call filter(files, 'fnamemodify(v:val, ":e") !=# ext')
    endfor

    return sort(files, g:nf_sort_funcref)
endfunc
" }}}
" s:get_next_idx {{{
func! s:get_next_idx(files, advance, cnt)
    try
        " get current file idx
        let tailed = map(copy(a:files), 'fnamemodify(v:val, ":t")')
        let idx = s:get_idx_of_list(tailed, expand('%:t'))
        " move to next or previous
        let idx = a:advance ? idx + a:cnt : idx - a:cnt
    catch /^not found$/
        " open the first file.
        let idx = 0
    endtry
    return idx
endfunc
" }}}
" s:open_next_file {{{
func! s:open_next_file(advance)
    if g:nf_disable_if_empty_name && expand('%') ==# ''
        return s:warn("current file is empty.")
    endif

    let files = s:get_files_list()
    if empty(files) | return | endif
    let idx   = s:get_next_idx(files, a:advance, v:count1)

    if 0 <= idx && idx < len(files)
        " can access to files[idx]
        execute g:nf_open_command fnameescape(files[idx])
    elseif g:nf_loop_files
        " wrap around
        if idx < 0
            " fortunately VimL supports negative index :)
            let idx = -(abs(idx) % len(files))
            " If you want to access to 'real' index, uncomment this.
            " if idx != 0
            "     let idx = len(files) + idx
            " endif
        else
            let idx = idx % len(files)
        endif
        execute g:nf_open_command fnameescape(files[idx])
    else
        call s:warnf('no %s file.', a:advance ? 'next' : 'previous')
    endif
endfunc
" }}}


" s:cmd_load_glob {{{
func! s:cmd_load_glob(...)
    let files = []
    for glob_expr in a:000
        " NOTE: load only 'files' currently
        let files += filter(s:glob_list(glob_expr), 'filereadable(v:val)')
    endfor
    " call sort(files, g:nf_sort_funcref)

    let save_pos   = getpos('.')
    let save_bufnr = bufnr('%')
    try
        for f in files
            " XXX: Adding :silent will NOT load anything. (Vim's bug?)
            execute 'edit' f
        endfor
    finally
        call setpos('.', save_pos)
        execute save_bufnr . 'buffer'
    endtry
endfunc
" }}}
" }}}

" MAPPING {{{
nnoremap <silent> <Plug>(nextfile-next) :<C-u>call <SID>open_next_file(1)<CR>
nnoremap <silent> <Plug>(nextfile-previous) :<C-u>call <SID>open_next_file(0)<CR>

if g:nf_map_next != ''
    execute 'silent! nmap <silent><unique>' g:nf_map_next '<Plug>(nextfile-next)'
endif
if g:nf_map_previous != ''
    execute 'silent! nmap <silent><unique>' g:nf_map_previous '<Plug>(nextfile-previous)'
endif
" }}}

" COMMANDS {{{
function s:define_commands()
    let command_def = {
    \   'NFLoadGlob' : ['-complete=file -nargs=+', 'call s:cmd_load_glob(<f-args>)'],
    \ }
    for [cmd, name] in items(g:nf_commands)
        if !empty(name)
            let [opt, def] = command_def[cmd]
            execute printf("command %s %s %s", opt, name, def)
        endif
    endfor
endfunction
call s:define_commands()
" }}}

" RESTORE CPO {{{
let &cpo = s:save_cpo
" }}}

