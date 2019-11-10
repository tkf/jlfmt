using Documenter, jlfmt

makedocs(;
    modules=[jlfmt],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/tkf/jlfmt/blob/{commit}{path}#L{line}",
    sitename="jlfmt",
    authors="Takafumi Arakaki <aka.tkf@gmail.com>",
    assets=String[],
)

deploydocs(;
    repo="github.com/tkf/jlfmt",
)
