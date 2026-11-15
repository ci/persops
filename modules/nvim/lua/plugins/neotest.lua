return {
  { "nvim-neotest/neotest-plenary" },
  { "jfpedroza/neotest-elixir" },
  {
    "nvim-neotest/neotest",
    opts = {
      adapters = {
        "neotest-plenary",
        "neotest-elixir",
        "neotest-python",
        "neotest-golang",
        "neotest-rspec",
      },
    },
  },
}
