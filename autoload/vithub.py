# ============================================================================
# File:        vithub.py
# Description: vim global plugin to visualize your undo tree
# Maintainer:  Steve Losh <steve@stevelosh.com>
# License:     GPLv2+ -- look it up.
# Notes:       Much of this code was thiefed from Mercurial, and the rest was
#              heavily inspired by scratch.vim and histwin.vim.
#
# ============================================================================

try:
    import ujson as json
except ImportError:
    import json

import os
import urlparse
import urllib
import sys
import vim

GITHUB_BASE = "https://api.github.com/"
GITHUB_ACCESS_TOKEN = None
remotes = None

class Remote(object):
    def __init__(self, user, repo):
        self.user = user
        self.repo = repo
        self.pull_requests = []

    @classmethod
    def from_remote_description(cls, line):
        i = line.index("@github.com")
        if i > 0:
            j = line.rindex(".git")
            ref = line[i+12:j] # 11 = len("@github.com")
            user, repo = ref.split("/")
            return cls(user, repo)
        else:
            return None

    @classmethod
    def preview_pull_request(cls, pull_request, width=45):
        if pull_request:
            return [
                str(pull_request["head"]["label"]),
                "",
            ] + str(pull_request["body"]).splitlines()
        return []

    def _fetch_pull_requests(self, page=1):
        global GITHUB_ACCESS_TOKEN
        url = urlparse.urljoin(GITHUB_BASE, "/repos/%s/%s/pulls" % (self.user, self.repo))
        params = {"page" : page}
        if GITHUB_ACCESS_TOKEN:
            params["access_token"] = GITHUB_ACCESS_TOKEN
        url += "?" + urllib.urlencode(params)
    
        try:
            fd = urllib.urlopen(url)
        except:
            # error handling?
            return None
        data = json.loads(fd.read())
        link_header = fd.headers.get("Link")
        if link_header and 'rel="next"' in link_header:
            data += self._fetch_pull_requests(page+1)
        return data

    def update_pull_requests(self):
        self.pull_requests = self._fetch_pull_requests()

    def show(self):
        result = []
        result.append("- %s/%s" % (self.user, self.repo))
        for pull_request in self.pull_requests:
            result.append(str("\t[%d] %s" % (pull_request["number"], pull_request["title"])))
        return result


# Python Vim utility functions -----------------------------------------------------
normal = lambda s: vim.command('normal %s' % s)

MISSING_BUFFER = "Cannot find Vithub's target buffer (%s)"
MISSING_WINDOW = "Cannot find window (%s) for Vithub's target buffer (%s)"

def _check_sanity():
    '''Check to make sure we're not crazy.

    Does the following things:

        * Make sure the target buffer still exists.
    '''
    b = int(vim.eval('g:vithub_target_n'))

    if not vim.eval('bufloaded(%d)' % b):
        vim.command('echo "%s"' % (MISSING_BUFFER % b))
        return False

    w = int(vim.eval('bufwinnr(%d)' % b))
    if w == -1:
        vim.command('echo "%s"' % (MISSING_WINDOW % (w, b)))
        return False

    return True

def _goto_window_for_buffer(b):
    w = int(vim.eval('bufwinnr(%d)' % int(b)))
    vim.command('%dwincmd w' % w)

def _goto_window_for_buffer_name(bn):
    b = vim.eval('bufnr("%s")' % bn)
    return _goto_window_for_buffer(b)


INLINE_HELP = '''\
" Vithub for %s (%d)
" %s/%s  - move between undo states
" p    - preview diff of selected and current states
" <cr> - revert to selected state

'''


# Vithub rendering ------------------------------------------------------------------

def _output_preview_text(lines):
    _goto_window_for_buffer_name('__Vithub_Preview__')
    vim.command('setlocal modifiable')
    vim.current.buffer[:] = lines
    vim.command('setlocal nomodifiable')

def _get_github_remotes():
    remotes = []
    already_seen = set()
    for line in os.popen("git remote -v", "r"):
        remote = Remote.from_remote_description(line)
        key = remote.user + remote.repo
        if remote is not None and key not in already_seen:
            remotes.append(remote)
            already_seen.add(key)
    for remote in remotes:
        remote.update_pull_requests()
    return remotes


def VithubRenderGraph():
    global remotes
    if not _check_sanity():
        return

    result = []
    remotes =  _get_github_remotes()
    for remote in remotes:
        result += remote.show()

    target = (vim.eval('g:vithub_target_f'), int(vim.eval('g:vithub_target_n')))
    mappings = (vim.eval('g:vithub_map_move_older'),
                vim.eval('g:vithub_map_move_newer'))

    if int(vim.eval('g:vithub_help')):
        header = (INLINE_HELP % (target + mappings)).splitlines()
    else:
        header = []

    vim.command('call s:VithubOpenGraph()')
    vim.command('setlocal modifiable')
    vim.current.buffer[:] = (header + result)
    vim.command('setlocal nomodifiable')

    vim.command('%d' % (len(header)+1))

def GetCurrentState():
    global remotes
    if not remotes:
        return None, None

    target_state = int(vim.eval('s:VithubGetTargetState()'))
    if int(vim.eval('g:vithub_help')):
        target_state -= len(INLINE_HELP.splitlines())

    for remote in remotes:
        target_state -= 1
        if not target_state:
            return remote, None
        for pull in remote.pull_requests:
            target_state -= 1
            if not target_state:
                return remote, pull
    return None, None

def VithubRenderPreview():
    global remotes
    remote, pull = GetCurrentState()

    _goto_window_for_buffer(vim.eval('g:vithub_target_n'))

    vim.command('call s:VithubOpenPreview()')

    preview = Remote.preview_pull_request(pull)
    _output_preview_text(preview)

    _goto_window_for_buffer_name('__Vithub__')

def VithubRenderChangePreview():
    global remotes
    if not _check_sanity():
        return
    remote, pull = GetCurrentState()

    _goto_window_for_buffer(vim.eval('g:vithub_target_n'))

    vim.command('call s:VithubOpenPreview()')

    preview = Remote.preview_pull_request(pull)
    _output_preview_text(preview)

    _goto_window_for_buffer_name('__Vithub__')

def initPythonModule():
    global GITHUB_ACCESS_TOKEN
    if sys.version_info[:2] < (2, 4):
        vim.command('let s:has_supported_python = 0')
    authed_requests = int(vim.eval('g:vithub_authed_requests'))
    if authed_requests:
        token = os.popen("git config --get github.token", "r").read().strip()
        GITHUB_ACCESS_TOKEN = token or None

    

