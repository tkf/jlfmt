module jlfmt

using ArgParse
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
        "--preview"
            help = "set `overwrite=false`"
            dest_name = "overwrite"
            action = :store_false
        "--verbose"
            action = :store_true
        "--always-for-in"
            dest_name = "always_for_in"
            action = :store_true
        "--diff"
            action = :store_true
        "paths"
            help = "paths to be formatted"
            nargs = '*'
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

function print_diff(a, b, opts=`--unified`; path=nothing)
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
            proc = run(pipeline(cmd; stdout=stdout, stderr=stderr); wait=false)
            @async write(pa, a)
            @async write(pb, b)
        end
        wait(proc)
        @assert fetch(proc).exitcode in (0, 1)
        return
    end
end

function main(args = ARGS)
    arguments = parse_args(args, parse_settings())
    if arguments !== nothing
        paths = pop!(arguments, "paths")
        show_diff = pop!(arguments, "diff")
        kwargs = Dict(Symbol(k) => v for (k, v) in arguments)

        if isempty(paths) || paths == ["-"]
            pop!(kwargs, :verbose, nothing)
            pop!(kwargs, :overwrite, nothing)
            text, indent = preprocess_indents(read(stdin, String))
            formatted = format_text(text; margin = 92 - indent, kwargs...)
            show_diff && return print_diff(text, formatted; path="-")
            print(join(
                (isempty(l) ? l : string(" "^indent, l) for l in split(formatted, "\n")),
                "\n",
            ))
            return
        end

        if show_diff
            pop!(kwargs, :verbose, nothing)
            pop!(kwargs, :overwrite, nothing)
            for p in paths
                text = read(p, String)
                formatted = format_text(text; kwargs...)
                print_diff(text, formatted; path=p)
            end
            return
        end

        format(paths; kwargs...)
    end
end

end # module
