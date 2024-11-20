# deck.jl

"""
    get_deck_names(ac::AnkiConnect) -> Vector{String}

Gets the complete list of deck names.
"""
function get_deck_names(ac::AnkiConnect)::Vector{String}
    result = request(ac, "deckNames")
    # Convert JSON3 array to Vector{String}
    collect(String, result)
end

"""
    create_deck!(ac::AnkiConnect, name::String) -> Int

Create a new deck with the given name. Returns deck ID.
"""
function create_deck!(ac::AnkiConnect, name::String)::Int
    result = request(ac, "createDeck", Dict{String,Any}("deck" => name))
    # Convert to Int explicitly since the API returns a large number
    convert(Int, result)
end

"""
    get_decks(ac::AnkiConnect, cards::Vector{Int}) -> Dict{String,Vector{Int}}

Gets mapping of deck names to card IDs for specified cards.
"""
function get_decks(ac::AnkiConnect, cards::Vector{Int})::Dict{String,Vector{Int}}
    result = request(ac, "getDecks", Dict{String,Any}("cards" => cards))
    # Convert JSON3 object to Dict with proper types
    Dict{String,Vector{Int}}(String(k) => collect(Int, v) for (k, v) in pairs(result))
end

"""
    delete_decks!(ac::AnkiConnect, names::Vector{String}) -> Nothing

Delete specified decks and their cards.
"""
function delete_decks!(ac::AnkiConnect, names::Vector{String})
    request(ac, "deleteDecks", Dict{String,Any}("decks" => names, "cardsToo" => true))
    nothing
end

"""
    change_deck!(ac::AnkiConnect, cards::Vector{Int}, deck::String) -> Nothing

Move specified cards to a different deck.
"""
function change_deck!(ac::AnkiConnect, cards::Vector{Int}, deck::String)
    request(ac, "changeDeck", Dict{String,Any}("cards" => cards, "deck" => deck))
    nothing
end
