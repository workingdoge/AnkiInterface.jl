# test/runtests.jl
using AnkiInterface
using Test

@testset "AnkiInterface.jl" begin
    @testset "Connection" begin
        @test try_connect()  # Should work if Anki is running
        @test !isnothing(get_connection())
    end

    @testset "Core Operations" begin
        # Test deck operations first
        @testset "Deck Operations" begin
            test_id = rand(1000:9999)
            test_deck = "test_deck_$test_id"

            # Create deck
            deck_id = create_deck!(test_deck)
            @test deck_id isa Int && deck_id > 0

            # Verify deck exists
            @test test_deck in get_deck_names()

            # Test note operations
            @test_nowarn begin
                test_note = NoteData(
                    test_deck,
                    "Basic",
                    fields = Dict{String,String}(
                        "Front" => "Test Question $test_id",
                        "Back" => "Test Answer $test_id",
                    ),
                    tags = ["test_tag_$test_id"],
                )

                note_id = add_note!(test_note)
                @test note_id isa Int && note_id > 0

                # Test note retrieval
                notes = get_notes_info([note_id])
                @test length(notes) == 1
                @test notes[1].fields["Front"]["value"] == "Test Question $test_id"
            end

            # Cleanup
            @test_nowarn delete_decks!([test_deck])
            @test !(test_deck in get_deck_names())
        end
    end

    @testset "Error Handling" begin
        # Test non-existent deck
        @test_throws AnkiError add_note!(
            NoteData(
                "NonexistentDeck",
                "Basic",
                fields = Dict{String,String}("Front" => "Test", "Back" => "Test"),
            ),
        )

        # Test invalid model
        @test_throws AnkiError add_note!(
            NoteData(
                "Default",
                "NonexistentModel",
                fields = Dict{String,String}("Front" => "Test", "Back" => "Test"),
            ),
        )
    end
end
