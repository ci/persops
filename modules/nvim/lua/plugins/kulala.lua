return {
  "mistweaverco/kulala.nvim",
  opts = {
    contenttypes = {
      ["application/json"] = {
        formatter = { "jq", "." },
      },
    },
    global_keymaps = true,
  },
}
