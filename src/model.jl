# Model Operations
"""
    ModelField

Represents a field in an Anki note type (model).

$(FIELDS)
"""
struct ModelField
    name::String
    font::String
    size::Int
    description::String
    sticky::Bool
    rtl::Bool
    order::Int

    function ModelField(
        name::String,
        order::Int;
        font::String = "Arial",
        size::Int = 20,
        description::String = "",
        sticky::Bool = false,
        rtl::Bool = false,
    )
        new(name, font, size, description, sticky, rtl, order)
    end
end
"""
    ModelTemplate

Represents a card template within a model.

$(FIELDS)
"""
struct ModelTemplate
    name::String
    front::String
    back::String
    styling::String
end

"""
    ModelConfig

Configuration for creating a new model.

$(FIELDS)
"""
struct ModelConfig
    name::String
    fields::Vector{ModelField}
    templates::Vector{ModelTemplate}
    css::String
    is_cloze::Bool
end

"""
    get_model_names(ac::AnkiConnect) -> Vector{String}

Get list of all available note type (model) names.
"""
function get_model_names(ac::AnkiConnect)::Vector{String}
    request(ac, "modelNames")
end

"""
    get_model_fields(ac::AnkiConnect, model::String) -> Vector{String}

Get field names for specified model.
"""
function get_model_fields(ac::AnkiConnect, model::String)::Vector{String}
    request(ac, "modelFieldNames", Dict("modelName" => model))
end

"""
    create_model!(ac::AnkiConnect, config::ModelConfig) -> Nothing

Create a new note type (model) based on configuration.
"""
function create_model!(ac::AnkiConnect, config::ModelConfig)
    # Prepare fields in order
    fields = sort(config.fields, by = f -> f.order)
    field_names = [f.name for f in fields]

    # Prepare templates
    templates = [
        Dict{String,Any}("Name" => t.name, "Front" => t.front, "Back" => t.back) for
        t in config.templates
    ]

    params = Dict{String,Any}(
        "modelName" => config.name,
        "inOrderFields" => field_names,
        "css" => config.css,
        "isCloze" => config.is_cloze,
        "cardTemplates" => templates,
    )

    request(ac, "createModel", params)
    nothing
end

"""
    get_model_templates(ac::AnkiConnect, model::String) -> Vector{ModelTemplate}

Get all card templates for a model.
"""
function get_model_templates(ac::AnkiConnect, model::String)::Vector{ModelTemplate}
    templates = request(ac, "modelTemplates", Dict("modelName" => model))
    styling = request(ac, "modelStyling", Dict("modelName" => model))

    result = ModelTemplate[]
    for (name, content) in templates
        push!(
            result,
            ModelTemplate(name, content["Front"], content["Back"], styling["css"]),
        )
    end
    return result
end

"""
    update_model_templates!(ac::AnkiConnect, model::String, templates::Vector{ModelTemplate}) -> Nothing

Update card templates for a model.
"""
function update_model_templates!(
    ac::AnkiConnect,
    model::String,
    templates::Vector{ModelTemplate},
)
    template_dict = Dict{String,Any}()

    for template in templates
        template_dict[template.name] =
            Dict{String,String}("Front" => template.front, "Back" => template.back)
    end

    params = Dict{String,Any}(
        "model" => Dict{String,Any}("name" => model, "templates" => template_dict),
    )

    request(ac, "updateModelTemplates", params)
    nothing
end

"""
    update_model_styling!(ac::AnkiConnect, model::String, css::String) -> Nothing

Update CSS styling for a model.
"""
function update_model_styling!(ac::AnkiConnect, model::String, css::String)
    params = Dict{String,Any}("model" => Dict{String,Any}("name" => model, "css" => css))

    request(ac, "updateModelStyling", params)
    nothing
end

"""
    find_and_replace_in_model!(ac::AnkiConnect, model::String, find::String, replace::String;
                              front::Bool=true, back::Bool=true, css::Bool=false) -> Int

Find and replace text in model templates and styling.
Returns number of replacements made.
"""
function find_and_replace_in_model!(
    ac::AnkiConnect,
    model::String,
    find::String,
    replace::String;
    front::Bool = true,
    back::Bool = true,
    css::Bool = false,
)::Int
    params = Dict{String,Any}(
        "model" => Dict{String,Any}(
            "modelName" => model,
            "findText" => find,
            "replaceText" => replace,
            "front" => front,
            "back" => back,
            "css" => css,
        ),
    )

    request(ac, "findAndReplaceInModels", params)::Int
end

"""
    set_model_field_descriptions!(ac::AnkiConnect, model::String, descriptions::Dict{String,String}) -> Nothing

Set field descriptions for empty fields in the note editor.
"""
function set_model_field_descriptions!(
    ac::AnkiConnect,
    model::String,
    descriptions::Dict{String,String},
)
    for (field, description) in descriptions
        params = Dict{String,Any}(
            "modelName" => model,
            "fieldName" => field,
            "description" => description,
        )
        request(ac, "modelFieldSetDescription", params)
    end
    nothing
end
