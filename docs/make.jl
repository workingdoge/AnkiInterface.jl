using AnkiInterface
using Documenter

DocMeta.setdocmeta!(AnkiInterface, :DocTestSetup, :(using AnkiInterface); recursive = true)

const page_rename = Dict("developer.md" => "Developer docs") # Without the numbers
const numbered_pages = [
    file for file in readdir(joinpath(@__DIR__, "src")) if
    file != "index.md" && splitext(file)[2] == ".md"
]

makedocs(;
    modules = [AnkiInterface],
    authors = "arj@workingdoge.com",
    repo = "https://github.com/workingdoge/AnkiInterface.jl/blob/{commit}{path}#{line}",
    sitename = "AnkiInterface.jl",
    format = Documenter.HTML(;
        canonical = "https://workingdoge.github.io/AnkiInterface.jl",
    ),
    pages = ["index.md"; numbered_pages],
)

deploydocs(; repo = "github.com/workingdoge/AnkiInterface.jl")
