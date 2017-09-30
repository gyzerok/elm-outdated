port module Main exposing (..)

import Platform
import Json.Decode as Decode
import Dict


---- MODEL ----


type alias Model =
    ()


type alias Registry =
    Dict.Dict String (List Version)


type alias Package =
    { name : String
    , version : Version
    }


type alias Version =
    { major : String
    , minor : String
    , patch : String
    }


type alias Report =
    { current : String
    , wanted : String
    , latest : String
    }


init : Decode.Value -> ( Model, Cmd msg )
init flags =
    let
        decoder =
            Decode.map2 (,)
                (Decode.field "elmPackageJson"
                    (Decode.at [ "dependencies" ] <|
                        Decode.keyValuePairs Decode.string
                    )
                )
                (Decode.field "registry" registryDecoder)

        { registry, deps } =
            case Decode.decodeValue decoder flags of
                Err _ ->
                    Debug.crash "Corrupted elm-package.json"

                Ok ( deps, registry ) ->
                    { registry = registry
                    , deps =
                        deps
                            |> List.map
                                (\( name, versionRange ) ->
                                    { name = name
                                    , version =
                                        String.split " " versionRange
                                            |> List.head
                                            |> unsafe
                                            |> versionFromString
                                            |> Result.toMaybe
                                            |> unsafe
                                    }
                                )
                    }

        reports =
            deps
                |> List.foldl
                    (\dep ->
                        Dict.insert dep.name <|
                            Maybe.map3 Report
                                (Just dep.version |> Maybe.map versionToString)
                                (wantedVersion registry dep |> Maybe.map versionToString)
                                (latestVersion registry dep |> Maybe.map versionToString)
                    )
                    Dict.empty
    in
        ( (), sendReports <| Dict.toList reports )


versionFromString : String -> Result String Version
versionFromString str =
    case String.split "." str of
        major :: minor :: patch :: [] ->
            Ok <| Version major minor patch

        _ ->
            Err "TODO"


versionToString : Version -> String
versionToString { major, minor, patch } =
    major ++ "." ++ minor ++ "." ++ patch


versionDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case versionFromString str of
                    Err e ->
                        Decode.fail e

                    Ok version ->
                        Decode.succeed version
            )


registryDecoder =
    Decode.map Dict.fromList <|
        Decode.list <|
            Decode.map2 (,)
                (Decode.field "name" Decode.string)
                (Decode.field "versions" <| Decode.list versionDecoder)


wantedVersion : Registry -> Package -> Maybe Version
wantedVersion registry package =
    let
        safeVersions =
            registry
                |> Dict.get package.name
                |> unsafe
                |> List.filter (\{ major } -> major == package.version.major)
    in
        case safeVersions of
            [] ->
                Debug.crash "TODO"

            versions ->
                List.head versions


latestVersion : Registry -> Package -> Maybe Version
latestVersion registry package =
    Dict.get package.name registry
        |> unsafe
        |> List.head



---- HELPERS ----


unsafe : Maybe a -> a
unsafe maybe =
    case maybe of
        Nothing ->
            Debug.crash "whatever"

        Just x ->
            x



---- PROGRAM ----


main : Program Decode.Value Model msg
main =
    Platform.programWithFlags
        { init = init
        , update = \msg model -> ( model, Cmd.none )
        , subscriptions = always Sub.none
        }


port sendReports : List ( String, Maybe Report ) -> Cmd msg
