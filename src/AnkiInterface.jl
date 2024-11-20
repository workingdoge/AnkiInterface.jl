module AnkiInterface

using HTTP
using JSON3
using DocStringExtensions
using MacroTools

# Core Types
export AnkiConnect, AnkiError, NoteData, RequestParams

"""
    AnkiError <: Exception

Represents errors returned from Anki-Connect API.

$(FIELDS)
"""
struct AnkiError <: Exception
    action::String
    message::String
end

"""
    AnkiConnect

Connection configuration for Anki-Connect API.
Default configuration uses localhost:8765 with API version 6.

$(FIELDS)
"""
struct AnkiConnect
    host::String
    port::Int
    version::Int

    AnkiConnect(; host = "localhost", port = 8765, version = 6) = new(host, port, version)
end

"""
    NoteData

Structured representation of an Anki note.

$(FIELDS)
"""
struct NoteData
    deck_name::String
    model_name::String
    fields::Dict{String,String}
    tags::Vector{String}
    options::Dict{String,Any}

    function NoteData(
        deck_name::String,
        model_name::String;
        fields::Dict{String,String} = Dict{String,String}(),
        tags::Vector{String} = String[],
        allow_duplicate::Bool = false,
        duplicate_scope::String = "deck",
        duplicate_scope_options::Dict{String,Any} = Dict{String,Any}(),
    )
        options = Dict{String,Any}(
            "allowDuplicate" => allow_duplicate,
            "duplicateScope" => duplicate_scope,
            "duplicateScopeOptions" => duplicate_scope_options,
        )
        new(deck_name, model_name, fields, tags, options)
    end
end

# Core API Request Structure
struct RequestParams
    action::String
    params::Dict{String,Any}
    version::Int
end

Base.Dict(p::RequestParams) =
    Dict("action" => p.action, "version" => p.version, "params" => p.params)

"""
    request(ac::AnkiConnect, params::RequestParams) -> Any

Make a request to AnkiConnect API with the given parameters.
"""
function request(ac::AnkiConnect, params::RequestParams)
    url = "http://$(ac.host):$(ac.port)"

    try
        response = HTTP.post(
            url,
            ["Content-Type" => "application/json"],
            JSON3.write(Dict(params)),
        )

        result = JSON3.read(String(response.body))

        if !isnothing(result.error)
            throw(AnkiError(params.action, result.error))
        end

        return result.result
    catch e
        if e isa HTTP.ExceptionRequest.StatusError
            throw(AnkiError(params.action, "HTTP error: $(e.status)"))
        elseif e isa JSON3.Error
            throw(AnkiError(params.action, "JSON parsing error: $(e)"))
        end
        rethrow()
    end
end

# Convenience wrapper for simple requests
request(ac::AnkiConnect, action::String, params::Dict{String,Any} = Dict{String,Any}()) =
    request(ac, RequestParams(action, params, ac.version))

"""
    create_implicit_methods(mod::Module)

Creates implicit versions of all AnkiConnect methods in the given module.
Should be called after all methods are defined.
"""
function create_implicit_methods(mod::Module)
    for name in Base.names(mod; all = true)
        # Skip special names and non-functions
        if !startswith(String(name), "#") && isdefined(mod, name)
            func = getfield(mod, name)
            if func isa Function
                # Get method signatures
                ms = methods(func)
                for m in ms
                    sig = m.sig
                    # Check if first argument is AnkiConnect
                    if length(sig.parameters) > 1 && sig.parameters[2] == AnkiConnect
                        # Create implicit version
                        args = sig.parameters[3:end]
                        arg_names = [Symbol("arg", i) for i = 1:length(args)]

                        # Build and evaluate the new method
                        new_method = quote
                            function $name(
                                $([:($an::$at) for (an, at) in zip(arg_names, args)]...),
                            )
                                if isnothing(GLOBAL_CONN.connection)
                                    throw(
                                        ErrorException(
                                            "Not connected to Anki. Call connect!() first.",
                                        ),
                                    )
                                end
                                $name(get_connection(), $(arg_names...))
                            end
                        end

                        Core.eval(mod, new_method)
                    end
                end
            end
        end
    end
end

include("deck.jl")
export get_deck_names,
    get_decks,
    create_deck!,
    delete_decks!,
    change_deck!,
    get_deck_config,
    save_deck_config!,
    get_deck_stats

include("note.jl")
# Note Operations
export add_note!,
    add_notes!,
    can_add_note,
    update_note!,
    get_note_tags,
    add_tags!,
    remove_tags!,
    find_notes,
    get_notes_info

include("model.jl")
export get_model_names,
    get_model_fields,
    create_model!,
    get_model_templates,
    update_model_templates!,
    update_model_styling!,
    ModelTemplate,
    ModelField,
    ModelConfig

mutable struct GlobalAnkiConnection
    connection::Union{Nothing,AnkiConnect}
    lock::ReentrantLock

    GlobalAnkiConnection() = new(nothing, ReentrantLock())
end

const GLOBAL_CONN = GlobalAnkiConnection()

# Export connection management functions
export connect!, try_connect, get_connection

"""
    connect!(; host="localhost", port=8765, version=6)

Manually connect to Anki. Throws error if connection fails.
"""
function connect!(; host = "localhost", port = 8765, version = 6)
    if !try_connect(host = host, port = port, version = version)
        throw(ErrorException("Failed to connect to Anki"))
    end
end

"""
    get_connection() -> AnkiConnect

Get the current Anki connection or throw if not connected.
"""
function get_connection()
    lock(GLOBAL_CONN.lock) do
        if isnothing(GLOBAL_CONN.connection)
            throw(ErrorException("Not connected to Anki. Call connect!() first."))
        end
        return GLOBAL_CONN.connection
    end
end
"""
    try_connect(; host="localhost", port=8765, version=6) -> Bool

Attempts to connect to Anki. Returns true if successful, false otherwise.
"""
function try_connect(; host = "localhost", port = 8765, version = 6)::Bool
    try
        # Create connection
        conn = AnkiConnect(host = host, port = port, version = version)

        # Test connection with simple request
        response = HTTP.post(
            "http://$host:$port",
            ["Content-Type" => "application/json"],
            JSON3.write(Dict("action" => "version", "version" => version)),
        )

        # If we got here, connection works
        lock(GLOBAL_CONN.lock) do
            GLOBAL_CONN.connection = conn
        end
        return true
    catch e
        @warn "Failed to connect to Anki" exception = e
        return false
    end
end

function __init__()
    create_implicit_methods(@__MODULE__)
    if try_connect()
        @info "Successfully connected to Anki"
    else
        @warn "Could not connect to Anki automatically. Call connect!() manually when Anki is running."
    end
end


end # module
