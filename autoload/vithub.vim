" ============================================================================
" File:        vithub.vim
" Description: vim global plugin to visualize and interact with github issues
"              and pull requests
" Maintainer:  Micha Gorelick <mynameisfiber@gmail.com>
" License:     GPLv2+ -- look it up.
" Notes:       Much of this code was thiefed from vithub
"
" ============================================================================


"{{{ Init

if v:version < '703'"{{{
    function! s:VithubDidNotLoad()
        echohl WarningMsg|echomsg "Vithub unavailable: requires Vim 7.3+"|echohl None
    endfunction
    command! -nargs=0 VithubToggle call s:VithubDidNotLoad()
    finish
endif"}}}

if !exists('g:vithub_width')"{{{
    let g:vithub_width = 45
endif"}}}
if !exists('g:vithub_preview_height')"{{{
    let g:vithub_preview_height = 15
endif"}}}
if !exists('g:vithub_preview_bottom')"{{{
    let g:vithub_preview_bottom = 0
endif"}}}
if !exists('g:vithub_right')"{{{
    let g:vithub_right = 0
endif"}}}
if !exists('g:vithub_help')"{{{
    let g:vithub_help = 1
endif"}}}
if !exists("g:vithub_map_move_older")"{{{
    let g:vithub_map_move_older = 'j'
endif"}}}
if !exists("g:vithub_map_move_newer")"{{{
    let g:vithub_map_move_newer = 'k'
endif"}}}
if !exists("g:vithub_close_on_revert")"{{{
    let g:vithub_close_on_revert = 0
endif"}}}
if !exists("g:vithub_prefer_python3")"{{{
    let g:vithub_prefer_python3 = 0
endif"}}}
if !exists("g:vithub_auto_preview")"{{{
    let g:vithub_auto_preview = 1
endif"}}}
if !exists("g:vithub_playback_delay")"{{{
    let g:vithub_playback_delay = 60
endif"}}}

let s:has_supported_python = 0
if g:vithub_prefer_python3 && has('python3')"{{{
    let s:has_supported_python = 2
elseif has('python')"
    let s:has_supported_python = 1
endif

if !s:has_supported_python
    function! s:VithubDidNotLoad()
        echohl WarningMsg|echomsg "Vithub requires Vim to be compiled with Python 2.4+"|echohl None
    endfunction
    command! -nargs=0 VithubToggle call s:VithubDidNotLoad()
    finish
endif"}}}

let s:plugin_path = escape(expand('<sfile>:p:h'), '\')
"}}}

"{{{ Vithub utility functions

function! s:VithubGetTargetState()"{{{
    return line(".") 
endfunction"}}}

function! s:VithubGoToWindowForBufferName(name)"{{{
    if bufwinnr(bufnr(a:name)) != -1
        exe bufwinnr(bufnr(a:name)) . "wincmd w"
        return 1
    else
        return 0
    endif
endfunction"}}}

function! s:VithubIsVisible()"{{{
    if bufwinnr(bufnr("__Vithub__")) != -1 || bufwinnr(bufnr("__Vithub_Preview__")) != -1
        return 1
    else
        return 0
    endif
endfunction"}}}

function! s:VithubInlineHelpLength()"{{{
    if g:vithub_help
        return 6
    else
        return 0
    endif
endfunction"}}}

"}}}

"{{{ Vithub buffer settings

function! s:VithubMapGraph()"{{{
    exec 'nnoremap <script> <silent> <buffer> ' . g:vithub_map_move_older . " :call <sid>VithubMove(1)<CR>"
    exec 'nnoremap <script> <silent> <buffer> ' . g:vithub_map_move_newer . " :call <sid>VithubMove(-1)<CR>"
    nnoremap <script> <silent> <buffer> <CR>          :call <sid>VithubRevert()<CR>
    nnoremap <script> <silent> <buffer> o             :call <sid>VithubRevert()<CR>
    nnoremap <script> <silent> <buffer> <down>        :call <sid>VithubMove(1)<CR>
    nnoremap <script> <silent> <buffer> <up>          :call <sid>VithubMove(-1)<CR>
    nnoremap <script> <silent> <buffer> gg            gg:call <sid>VithubMove(1)<CR>
    nnoremap <script> <silent> <buffer> P             :call <sid>VithubPlayTo()<CR>
    nnoremap <script> <silent> <buffer> p             :call <sid>VithubRenderChangePreview()<CR>
    nnoremap <script> <silent> <buffer> r             :call <sid>VithubRenderPreview()<CR>
    nnoremap <script> <silent> <buffer> q             :call <sid>VithubClose()<CR>
    cabbrev  <script> <silent> <buffer> q             call <sid>VithubClose()
    cabbrev  <script> <silent> <buffer> quit          call <sid>VithubClose()
    nnoremap <script> <silent> <buffer> <2-LeftMouse> :call <sid>VithubMouseDoubleClick()<CR>
endfunction"}}}

function! s:VithubMapPreview()"{{{
    nnoremap <script> <silent> <buffer> q     :call <sid>VithubClose()<CR>
    cabbrev  <script> <silent> <buffer> q     call <sid>VithubClose()
    cabbrev  <script> <silent> <buffer> quit  call <sid>VithubClose()
endfunction"}}}

function! s:VithubSettingsGraph()"{{{
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=vithub
    setlocal nolist
    setlocal nonumber
    setlocal norelativenumber
    setlocal nowrap
    call s:VithubSyntaxGraph()
    call s:VithubMapGraph()
endfunction"}}}

function! s:VithubSettingsPreview()"{{{
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=diff
    setlocal nonumber
    setlocal norelativenumber
    setlocal wrap
    setlocal foldlevel=20
    setlocal foldmethod=diff
    call s:VithubMapPreview()
    call s:VithubSyntaxPreview()
endfunction"}}}

function! s:VithubSyntaxGraph()"{{{
    let b:current_syntax = 'vithub'

    syn match VithubCurrentLocation '@'
    syn match VithubHelp '\v^".*$'
    syn match VithubNumberField '\v\[[0-9]+\]'
    syn match VithubNumber '\v[0-9]+' contained containedin=VithubNumberField

    hi def link VithubCurrentLocation Keyword
    hi def link VithubHelp Comment
    hi def link VithubNumberField Comment
    hi def link VithubNumber Identifier
endfunction"}}}

function! s:VithubSyntaxPreview()"{{{
    let b:current_syntax = 'vithub'

    syn match VithubMention '@[^ ]\+'
    syn match VithubReference '#[0-9]\+'
    syn match VithubLabel '^[^: ]\+:[^ ]\+$'

    hi def link VithubMention Keyword
    hi def link VithubReference Function
    hi def link VithubLabel Constant
endfunction"}}}

"}}}

"{{{ Vithub buffer/window management

function! s:VithubBufferWidth()"{{{
    return winwidth('__Vithub__')
endfunction"}}}

function! s:VithubResizeBuffers(backto)"{{{
    call s:VithubGoToWindowForBufferName('__Vithub__')
    exe "vertical resize " . g:vithub_width

    call s:VithubGoToWindowForBufferName('__Vithub_Preview__')
    exe "resize " . g:vithub_preview_height

    exe a:backto . "wincmd w"
endfunction"}}}

function! s:VithubOpenGraph()"{{{
    let existing_vithub_buffer = bufnr("__Vithub__")

    if existing_vithub_buffer == -1
        call s:VithubGoToWindowForBufferName('__Vithub_Preview__')
        exe "new __Vithub__"
        if g:vithub_preview_bottom
            if g:vithub_right
                wincmd L
            else
                wincmd H
            endif
        endif
        call s:VithubResizeBuffers(winnr())
    else
        let existing_vithub_window = bufwinnr(existing_vithub_buffer)

        if existing_vithub_window != -1
            if winnr() != existing_vithub_window
                exe existing_vithub_window . "wincmd w"
            endif
        else
            call s:VithubGoToWindowForBufferName('__Vithub_Preview__')
            if g:vithub_preview_bottom
                if g:vithub_right
                    exe "botright vsplit +buffer" . existing_vithub_buffer
                else
                    exe "topleft vsplit +buffer" . existing_vithub_buffer
                endif
            else
                exe "split +buffer" . existing_vithub_buffer
            endif
            call s:VithubResizeBuffers(winnr())
        endif
    endif
    if exists("g:vithub_tree_statusline")
        let &l:statusline = g:vithub_tree_statusline
    endif
endfunction"}}}

function! s:VithubOpenPreview()"{{{
    let existing_preview_buffer = bufnr("__Vithub_Preview__")

    if existing_preview_buffer == -1
        if g:vithub_preview_bottom
            exe "botright new __Vithub_Preview__"
        else
            if g:vithub_right
                exe "botright vnew __Vithub_Preview__"
            else
                exe "topleft vnew __Vithub_Preview__"
            endif
        endif
    else
        let existing_preview_window = bufwinnr(existing_preview_buffer)

        if existing_preview_window != -1
            if winnr() != existing_preview_window
                exe existing_preview_window . "wincmd w"
            endif
        else
            if g:vithub_preview_bottom
                exe "botright split +buffer" . existing_preview_buffer
            else
                if g:vithub_right
                    exe "botright vsplit +buffer" . existing_preview_buffer
                else
                    exe "topleft vsplit +buffer" . existing_preview_buffer
                endif
            endif
        endif
    endif
    if exists("g:vithub_preview_statusline")
        let &l:statusline = g:vithub_preview_statusline
    endif
endfunction"}}}

function! s:VithubClose()"{{{
    if s:VithubGoToWindowForBufferName('__Vithub__')
        quit
    endif

    if s:VithubGoToWindowForBufferName('__Vithub_Preview__')
        quit
    endif

    exe bufwinnr(g:vithub_target_n) . "wincmd w"
endfunction"}}}

function! s:VithubOpen()"{{{
    if !exists('g:vithub_py_loaded')
        if s:has_supported_python == 2 && g:vithub_prefer_python3
            exe 'py3file ' . s:plugin_path . '/vithub.py'
            python3 initPythonModule()
        else
            exe 'pyfile ' . s:plugin_path . '/vithub.py'
            python initPythonModule()
        endif

        if !s:has_supported_python
            function! s:VithubDidNotLoad()
                echohl WarningMsg|echomsg "Vithub unavailable: requires Vim 7.3+"|echohl None
            endfunction
            command! -nargs=0 VithubToggle call s:VithubDidNotLoad()
            call s:VithubDidNotLoad()
            return
        endif"

        let g:vithub_py_loaded = 1
    endif

    " Save `splitbelow` value and set it to default to avoid problems with
    " positioning new windows.
    let saved_splitbelow = &splitbelow
    let &splitbelow = 0

    call s:VithubOpenPreview()
    exe bufwinnr(g:vithub_target_n) . "wincmd w"

    call s:VithubRenderGraph()
    call s:VithubRenderPreview()

    " Restore `splitbelow` value.
    let &splitbelow = saved_splitbelow
endfunction"}}}

function! s:VithubToggle()"{{{
    if s:VithubIsVisible()
        call s:VithubClose()
    else
        let g:vithub_target_n = bufnr('')
        let g:vithub_target_f = @%
        call s:VithubOpen()
    endif
endfunction"}}}

function! s:VithubShow()"{{{
    if !s:VithubIsVisible()
        let g:vithub_target_n = bufnr('')
        let g:vithub_target_f = @%
        call s:VithubOpen()
    endif
endfunction"}}}

function! s:VithubHide()"{{{
    if s:VithubIsVisible()
        call s:VithubClose()
    endif
endfunction"}}}

"}}}

"{{{ Vithub mouse handling

function! s:VithubMouseDoubleClick()"{{{
    let start_line = getline('.')

    if stridx(start_line, '[') == -1
        return
    else
        call s:VithubRevert()
    endif
endfunction"}}}

"}}}

"{{{ Vithub movement

function! s:VithubMove(direction) range"{{{
    let target_n = line('.') + (a:direction)

    " Bound the movement to the graph.
    if target_n <= s:VithubInlineHelpLength() - 1
        call cursor(s:VithubInlineHelpLength(), 0)
    else
        call cursor(target_n, 0)
    endif

    let line = getline('.')

    " Move to the node, whether it's an @ or an o
    let idx1 = stridx(line, '[')
    if idx1 != -1
        call cursor(0, idx1 + 1)
    endif

    if g:vithub_auto_preview == 1
        call s:VithubRenderPreview()
    endif
endfunction"}}}

"}}}

"{{{ Vithub rendering

function! s:VithubRenderGraph()"{{{
    if s:has_supported_python == 2 && g:vithub_prefer_python3
        python3 VithubRenderGraph()
    else
        python VithubRenderGraph()
    endif
endfunction"}}}

function! s:VithubRenderPreview()"{{{
    if s:has_supported_python == 2 && g:vithub_prefer_python3
        python3 VithubRenderPreview()
    else
        python VithubRenderPreview()
    endif
endfunction"}}}

function! s:VithubRenderChangePreview()"{{{
    if s:has_supported_python == 2 && g:vithub_prefer_python3
        python3 VithubRenderChangePreview()
    else
        python VithubRenderChangePreview()
    endif
endfunction"}}}

"}}}

"{{{ Misc

function! vithub#VithubToggle()"{{{
    call s:VithubToggle()
endfunction"}}}

function! vithub#VithubShow()"{{{
    call s:VithubShow()
endfunction"}}}

function! vithub#VithubHide()"{{{
    call s:VithubHide()
endfunction"}}}

function! vithub#VithubRenderGraph()"{{{
    call s:VithubRenderGraph()
endfunction"}}}

augroup VithubAug
    autocmd!
    autocmd BufNewFile __Vithub__ call s:VithubSettingsGraph()
    autocmd BufNewFile __Vithub_Preview__ call s:VithubSettingsPreview()
augroup END

"}}}
