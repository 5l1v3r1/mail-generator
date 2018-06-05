module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Email
import Notes exposing (Note, Notes)
import Ports
import Date exposing (..)
import Task exposing (..)
import Dict exposing (..)
import Settings exposing (Settings)


type alias Model =
    { value : String
    , emails : List Email.Email
    , notes : Notes
    , settings : Settings
    }


type Msg
    = Input String
    | GenerateNewMail
    | GenerateAdditionalMail Email.Email
    | SaveGeneratedEmail Email.Email Date
    | ClearEmailsList
    | RemoveEmail String
    | ReceivedEmails (List Email.Email)
    | ReceivedNotes (List ( String, Note ))
    | Copy String
    | AutoClipboard Bool
    | UpdateNote Email.Id Note
    | ReceivedSettings (Maybe Settings)
    | SetBaseDomain String


initialModel : Model
initialModel =
    { value = ""
    , emails = []
    , settings =
        { autoClipboard = True
        , baseDomain = Email.initialHost
        }
    , notes = Dict.empty
    }


init : ( Model, Cmd Msg )
init =
    ( initialModel, Cmd.batch [ Ports.getEmails (), Ports.getNotes (), Ports.getSettings () ] )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Input value ->
            ( { model | value = value }, Cmd.none )

        GenerateNewMail ->
            let
                email =
                    Email.generateEmail model.value model.emails model.settings.baseDomain
            in
                ( model, Task.perform (SaveGeneratedEmail email) Date.now )

        GenerateAdditionalMail baseEmail ->
            let
                email =
                    Email.generateAdditionalEmail baseEmail model.emails
            in
                ( model, Task.perform (SaveGeneratedEmail email) Date.now )

        SaveGeneratedEmail email date ->
            let
                emailWithDate =
                    { email | createdAt = toString date }

                effect =
                    if model.settings.autoClipboard then
                        Cmd.batch [ Ports.storeEmail emailWithDate, Ports.copy emailWithDate.id ]
                    else
                        Ports.storeEmail emailWithDate
            in
                ( { model | emails = List.append model.emails [ emailWithDate ] }, effect )

        ClearEmailsList ->
            ( { model | emails = [] }, Ports.removeAllEmails () )

        RemoveEmail droppedEmail ->
            ( { model | emails = List.filter (\email -> email.id /= droppedEmail) model.emails }, Ports.removeEmail droppedEmail )

        ReceivedEmails emails ->
            ( { model | emails = List.concat [ model.emails, emails ] }, Cmd.none )

        Copy address ->
            ( model, Ports.copy address )

        AutoClipboard value ->
            let
                settings =
                    model.settings

                newSettings =
                    { settings | autoClipboard = value }
            in
                ( { model | settings = newSettings }, Ports.storeSettings newSettings )

        UpdateNote emailId content ->
            let
                updatedNotes =
                    Dict.update emailId (\_ -> Just content) model.notes
            in
                ( { model | notes = updatedNotes }, Ports.storeNote ( emailId, content ) )

        ReceivedNotes notes ->
            ( { model | notes = Dict.fromList notes }, Cmd.none )

        ReceivedSettings settings ->
            case settings of
                Just s ->
                    ( { model | settings = s }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        SetBaseDomain domain ->
            let
                settings =
                    model.settings

                newSettings =
                    { settings | baseDomain = domain }
            in
                ( { model | settings = newSettings }, Ports.storeSettings newSettings )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ Ports.receiveEmails ReceivedEmails, Ports.receiveNotes ReceivedNotes, Ports.receiveSettings ReceivedSettings ]


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


view : Model -> Html Msg
view model =
    div []
        [ h1 [] [ text "Mail generator" ]
        , mailForm model
        , domainSaver model.value model.settings.baseDomain
        , mailsList model.emails model.notes
        ]


mailInput : Html Msg
mailInput =
    input
        [ placeholder "Mail address"
        , onInput Input
        ]
        []


mailsList : List Email.Email -> Notes -> Html Msg
mailsList emails notes =
    div []
        [ ul [] (List.reverse (mailItems emails notes))
        , if List.isEmpty emails then
            text ""
          else
            button [ type_ "button", onClick ClearEmailsList ] [ text "Clear" ]
        ]


mailItems : List Email.Email -> Notes -> List (Html Msg)
mailItems emails notes =
    List.map (\email -> mailItem email (Dict.get email.id notes)) emails


mailItem : Email.Email -> Maybe Note -> Html Msg
mailItem email note =
    li []
        [ text email.id
        , displayDate email.createdAt
        , button [ onClick (Copy email.id) ] [ text "Copy" ]
        , button [ onClick (GenerateAdditionalMail email) ] [ text "New" ]
        , button [ onClick (RemoveEmail email.id) ] [ text "Remove" ]
        , noteView email.id note
        ]


noteView : String -> Maybe Note -> Html Msg
noteView id note =
    let
        noteContent =
            case note of
                Just v ->
                    v

                Nothing ->
                    ""
    in
        div []
            [ textarea
                [ value noteContent
                , onInput (UpdateNote id)
                ]
                []
            , button
                [ onClick (UpdateNote id "") ]
                [ text "Clear" ]
            ]


mailForm : Model -> Html Msg
mailForm { value, settings } =
    Html.form
        [ onSubmit GenerateNewMail ]
        [ mailInput
        , hostAddition value settings.baseDomain
        , button [] [ text "Generate" ]
        , label []
            [ input
                [ onCheck AutoClipboard
                , type_ "checkbox"
                , checked settings.autoClipboard
                ]
                []
            , text "Save to clipboard"
            ]
        ]


hostAddition : String -> String -> Html Msg
hostAddition value baseDomain =
    let
        ( userName, host ) =
            Email.splitAddress value baseDomain

        hostColor =
            if host == baseDomain && not (String.contains baseDomain value) then
                "gray"
            else
                "transparent"

        atColor =
            if String.contains "@" value then
                "transparent"
            else
                "gray"

        userNamePlaceholder =
            span [ style [ ( "color", "transparent" ) ] ] [ text userName ]

        atPlaceholder =
            span [ style [ ( "color", atColor ) ] ] [ text "@" ]

        hostPlaceholder =
            span [ style [ ( "color", hostColor ) ] ] [ text host ]
    in
        div []
            [ userNamePlaceholder
            , atPlaceholder
            , hostPlaceholder
            ]


displayDate : String -> Html Msg
displayDate date =
    case Date.fromString date of
        Ok d ->
            let
                dateContent =
                    [ Date.day d, Date.hour d, Date.minute d ]
                        |> List.map (\v -> toString v)
                        |> String.join "_"
            in
                span
                    [ style [ ( "margin", ("10px") ) ] ]
                    [ text (toString (Date.month d) ++ "_" ++ dateContent) ]

        Err err ->
            text ""


domainSaver : String -> String -> Html Msg
domainSaver value baseDomain =
    let
        ( _, host ) =
            Email.splitAddress value baseDomain

        textContent =
            "Save " ++ host ++ " domain as a default."
    in
        button
            [ disabled (host == baseDomain)
            , onClick (SetBaseDomain host)
            ]
            [ text textContent ]
