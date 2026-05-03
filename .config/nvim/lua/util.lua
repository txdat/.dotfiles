local M = {}

function M.keymap(mode, lhs, rhs, opts)
    local options = { noremap = true, silent = true }
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    vim.keymap.set(mode, lhs, rhs, options)
end

function M.system_cmd(cmd)
    return vim.fn.system(cmd):gsub("\n[^\n]*$", "")
end

function M.merge_tables(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            M.merge_tables(target[k], v)
        else
            target[k] = v
        end
    end
    return target
end

return M
