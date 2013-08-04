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
if !exists('g:vithub_debug') && (exists('g:vithub_disable') || exists('loaded_vithub') || &cp)"{{{
    finish
endif
let loaded_vithub = 1"}}}
"}}}

"{{{ Misc
command! -nargs=0 VithubToggle call vithub#VithubToggle()
command! -nargs=0 VithubShow call vithub#VithubShow()
command! -nargs=0 VithubHide call vithub#VithubHide()
command! -nargs=0 VithubRenderGraph call vithub#VithubRenderGraph()
"}}}
