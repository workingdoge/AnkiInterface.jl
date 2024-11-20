"""
    NoteInfo

Detailed information about an Anki note.

$(FIELDS)
"""
struct NoteInfo
    id::Int
    model_name::String
    tags::Vector{String}
    fields::Dict{String,Dict{String,Any}}  # field_name => Dict("value" => x, "order" => y)
    modified::Int
    cards::Vector{Int}
end

"""
    add_note!(ac::AnkiConnect, note::NoteData) -> Int

Creates a new note using the given deck and model. Returns note ID if successful.
"""
function add_note!(ac::AnkiConnect, note::NoteData)::Int
    params = Dict{String,Any}(
        "note" => Dict{String,Any}(
            "deckName" => note.deck_name,
            "modelName" => note.model_name,
            "fields" => note.fields,
            "options" => note.options,
            "tags" => note.tags,
        ),
    )

    result = request(ac, "addNote", params)
    convert(Int, result)
end

"""
    add_notes!(ac::AnkiConnect, notes::Vector{NoteData}) -> Vector{Union{Int,Nothing}}

Attempts to create multiple notes at once. Returns vector of note IDs (Nothing for failed notes).
"""
function add_notes!(ac::AnkiConnect, notes::Vector{NoteData})::Vector{Union{Int,Nothing}}
    params = Dict{String,Any}(
        "notes" => [
            Dict{String,Any}(
                "deckName" => note.deck_name,
                "modelName" => note.model_name,
                "fields" => note.fields,
                "options" => note.options,
                "tags" => note.tags,
            ) for note in notes
        ],
    )

    result = request(ac, "addNotes", params)
    [x === nothing ? nothing : convert(Int, x) for x in result]
end

"""
    can_add_note(ac::AnkiConnect, note::NoteData) -> Tuple{Bool,String}

Check if a note can be added and get error details if not.
Returns (can_add::Bool, error_message::String).
"""
function can_add_note(ac::AnkiConnect, note::NoteData)::Tuple{Bool,String}
    params = Dict{String,Any}(
        "notes" => [
            Dict{String,Any}(
                "deckName" => note.deck_name,
                "modelName" => note.model_name,
                "fields" => note.fields,
                "options" => note.options,
                "tags" => note.tags,
            ),
        ],
    )

    result = request(ac, "canAddNotesWithErrorDetail", params)
    detail = first(result)
    return (Bool(detail.canAdd), get(detail, :error, ""))
end

"""
    update_note!(ac::AnkiConnect, note_id::Int; fields=nothing, tags=nothing) -> Nothing

Update an existing note's fields and/or tags. At least one must be specified.
"""
function update_note!(
    ac::AnkiConnect,
    note_id::Int;
    fields::Union{Nothing,Dict{String,String}} = nothing,
    tags::Union{Nothing,Vector{String}} = nothing,
)
    if isnothing(fields) && isnothing(tags)
        throw(ArgumentError("Either fields or tags must be specified for update"))
    end

    params = Dict{String,Any}("note" => Dict{String,Any}("id" => note_id))

    if !isnothing(fields)
        params["note"]["fields"] = fields
    end

    if !isnothing(tags)
        params["note"]["tags"] = tags
    end

    request(ac, "updateNote", params)
    nothing
end

"""
    get_note_tags(ac::AnkiConnect, note_id::Int) -> Vector{String}

Get all tags for a specific note.
"""
function get_note_tags(ac::AnkiConnect, note_id::Int)::Vector{String}
    result = request(ac, "getNoteTags", Dict{String,Any}("note" => note_id))
    collect(String, result)
end

"""
    add_tags!(ac::AnkiConnect, note_ids::Vector{Int}, tags::String) -> Nothing

Add tags to specified notes.
"""
function add_tags!(ac::AnkiConnect, note_ids::Vector{Int}, tags::String)
    request(ac, "addTags", Dict{String,Any}("notes" => note_ids, "tags" => tags))
    nothing
end

"""
    remove_tags!(ac::AnkiConnect, note_ids::Vector{Int}, tags::String) -> Nothing

Remove tags from specified notes.
"""
function remove_tags!(ac::AnkiConnect, note_ids::Vector{Int}, tags::String)
    request(ac, "removeTags", Dict{String,Any}("notes" => note_ids, "tags" => tags))
    nothing
end

"""
    find_notes(ac::AnkiConnect, query::String) -> Vector{Int}

Search for notes using Anki query syntax. Returns matching note IDs.
"""
function find_notes(ac::AnkiConnect, query::String)::Vector{Int}
    result = request(ac, "findNotes", Dict{String,Any}("query" => query))
    collect(Int, result)
end

"""
    get_notes_info(ac::AnkiConnect, note_ids::Vector{Int}) -> Vector{NoteInfo}

Get detailed information about specified notes.
"""
function get_notes_info(ac::AnkiConnect, note_ids::Vector{Int})::Vector{NoteInfo}
    result = request(ac, "notesInfo", Dict{String,Any}("notes" => note_ids))

    map(result) do note
        NoteInfo(
            convert(Int, note.noteId),
            String(note.modelName),
            collect(String, note.tags),
            Dict(
                String(name) => Dict{String,Any}(
                    "value" => String(field.value),
                    "order" => convert(Int, field.order),
                ) for (name, field) in pairs(note.fields)
            ),
            convert(Int, note.mod),
            collect(Int, note.cards),
        )
    end
end
