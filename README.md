# vim-multiselect

A library plugin to handle multiple visual selections

**!!! This is a highly experimental plugin. Its behavior might be changed a lot for future. !!!**

# Mission

To explore the new ability of Vim to edit texts, here is a conceptual implementation to handle multiple selections. This plugin itself just provides basic functions to select and unselect regions on a buffer, and the further editing operations would be supplied by other external plugins. Its Application Programming Interfaces are opened. Hope it would spawn fresh ideas!

# Dependency

- Vim 8.0 or higher

# Usage

This plugin does not define default keymappings. Thus you should make your keymappings as you prefer. However, there are examples in `macros/multiselect/keymap/` directry. You also can use them by copying them into your vimrc or by `:runtime` command.

```vim
runtime macros/multiselect/keymap/example1.vim
```

## Check
Use **\<Plug\>(multiselect)**, **\<Plug\>(multiselect-check)**, **\<Plug\>(multiselect-checksearched)** to select regions on a buffer.

**\<Plug\>(multiselect)** selects a word under the cursor over the current buffer.

```vim
nmap <Space>v <Plug>(multiselect)
xmap <Space>v <Plug>(multiselect)
```

**\<Plug\>(multiselect-check)** selects a word under the cursor.

```vim
nmap <Space>v <Plug>(multiselect-check)
xmap <Space>v <Plug>(multiselect-check)
```

**\<Plug\>(multiselect-checksearched)** selects texts matching with the last searched pattern.

```vim
nmap <Space>v <Plug>(multiselect-checksearched)
xmap <Space>v <Plug>(multiselect-checksearched)
```

Another way is to use a series of wrapped textobjects, **broadcasting textobjects**. These textobjects works just as an original textobjects only except in linewise-visual mode. In line-wise visual mode, it tries to use the original textobject for each lines of selection at the cursor column. If it is succeeded, the region will be multiselected.
- `<Plug>(multiselect-iw)`
- `<Plug>(multiselect-aw)`
- `<Plug>(multiselect-iW)`
- `<Plug>(multiselect-aW)`
- `<Plug>(multiselect-i')`
- `<Plug>(multiselect-a')`
- `<Plug>(multiselect-i")`
- `<Plug>(multiselect-a")`
- ``<Plug>(multiselect-i`)``
- ``<Plug>(multiselect-a`)``
- `<Plug>(multiselect-i()`
- `<Plug>(multiselect-a()`
- `<Plug>(multiselect-i[)`
- `<Plug>(multiselect-a[)`
- `<Plug>(multiselect-i{)`
- `<Plug>(multiselect-a{)`
- `<Plug>(multiselect-it)`
- `<Plug>(multiselect-at)`

```vim
xmap iw <Plug>(multiselect-iw)
xmap i( <Plug>(multiselect-i()
xmap i' <Plug>(multiselect-i')
```

![demo:broadcasting textobjects](https://imgur.com/0HDDUE9.gif)


## Uncheck
Use **\<Plug\>(multiselect-uncheck)** or `<Plug>(multiselect-uncheckall)` to unselect the selections.

**\<Plug\>(multiselect-uncheck)** unselects a selection under the cursor.

```vim
nmap <Space>V <Plug>(multiselect-uncheck)
xmap <Space>V <Plug>(multiselect-uncheck)
```

**\<Plug\>(multiselect-uncheckall)** unselects all selections.

```vim
nmap <Space>V <Plug>(multiselect-uncheckall)
xmap <Space>V <Plug>(multiselect-uncheckall)
```


# Got interested?

Check out [vim-masquerade](https://github.com/machakann/vim-masquerade)!
