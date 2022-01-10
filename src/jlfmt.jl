module jlfmt

import Pkg
using ArgParse: @add_arg_table, ArgParseSettings, parse_args, usage_string
using Base: UUID
using JuliaFormatter: JuliaFormatter, format, format_text

function exc_handler(settings, err)
    error(string(err.text, "\n", usage_string(settings)))
end

function parse_settings()
    description = """
    A CLI to run `JuliaFormatter.format`.
    """
    setting = ArgParseSettings(
        prog = "jlfmt",
        description = description,
        exit_after_help = false,
        exc_handler = exc_handler,
    )

    #! format: off
    @add_arg_table setting begin
        "--version"
            dest_name = "version"
            action = :store_true
            help = """
            Print version.
            """
        "--preview"
            dest_name = "overwrite"
            action = :store_false
            help = """
            Set `overwrite=false`.  If it is specified, the formatted
            version of file named `foo.jl` will be written to
            `foo_fmt.jl`.
            """
        "--verbose"
            action = :store_true
            help = """
            Print the name of the file being formatted along with
            relevant details to `stdout`.
            """
        "--always-for-in"
            dest_name = "always_for_in"
            action = :store_true
            help = """
            Always use `in` keyword for `for` loops.
            """
        "--diff"
            action = :store_true
            help = """
            Show diff using `colordiff` or `diff` command instead of writing
            the result to the original files.
            """
        "paths"
            nargs = '*'
            help = """
            Paths to be formatted.  Recursively search Julia files if
            directories are passed.  Read content from stdin if no
            path or a single `-` is specified.
            """
    end
    #! format: on
end

function preprocess_indents(text)
    lines = split(text, "\n")
    lens = [length(match(r" *", l).match) for l in lines if match(r"^ *$", l) === nothing]
    isempty(lens) && return text, 0
    indent = minimum(lens)
    return join((chop(line, head = indent, tail = 0) for line in lines), "\n"), indent
end

function print_diff(a, b, opts = `--unified`; path = nothing)
    prog = something(Sys.which.(("colordiff", "diff"))...)
    if path !== nothing
        opts = `--label a/$path --label b/$path $opts`
    end
    mktempdir() do dir
        pa = joinpath(dir, "a")
        pb = joinpath(dir, "b")
        cmd = `$prog $opts $pa $pb`
        run(`mkfifo $pa $pb`)
        local proc
        @sync begin
            proc = run(pipeline(cmd; stdout = stdout, stderr = stderr); wait = false)
            @async write(pa, a)
            @async write(pb, b)
        end
        wait(proc)
        @assert fetch(proc).exitcode in (0, 1)
        return
    end
end

function print_version(io::IO = stdout)
    deps = Pkg.dependencies()
    info = (
        jlfmt = get(deps, UUID("f15eac7f-9c89-472e-a5bb-5f47caaa2526"), nothing),
        JuliaFormatter = get(deps, UUID("98e50ef6-434e-11e9-1051-2b60c6c9e899"), nothing),
        ArgParse = get(deps, UUID("c7e460c6-2fb9-53a9-8c5b-16f535851c63"), nothing),
    )
    for (k, pkginfo) in pairs(info)
        v = if pkginfo === nothing
            "<unknown version>"
        else
            pkginfo.version
        end
        println(io, k, " ", v)
    end
    println(io, "julia ", VERSION)
    println(io, "in project: ", Base.active_project())
end

function main(args = ARGS)
    arguments = parse_args(args, parse_settings())
    if arguments !== nothing
        if pop!(arguments, "version")
            print_version()
            return
        end

        paths = pop!(arguments, "paths")
        show_diff = pop!(arguments, "diff")
        kwargs = Dict(Symbol(k) => v for (k, v) in arguments)

        if isempty(paths) || paths == ["-"]
            pop!(kwargs, :verbose, nothing)
            pop!(kwargs, :overwrite, nothing)
            text, indent = preprocess_indents(read(stdin, String))
            formatted = format_text(text; margin = 92 - indent, kwargs...)
            show_diff && return print_diff(text, formatted; path = "-")
            lines = (isempty(l) ? l : string(" "^indent, l) for l in split(formatted, "\n"))
            print(join(lines, "\n"))
            return
        end

        if show_diff
            pop!(kwargs, :verbose, nothing)
            pop!(kwargs, :overwrite, nothing)
            for p in paths
                text = read(p, String)
                formatted = format_text(text; kwargs...)
                print_diff(text, formatted; path = p)
            end
            return
        end

        format(paths; kwargs...)
    end
end

end # module
