port module Old exposing (..)

import Dict
import Json.Decode as Decode
import Platform


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
    case decodeFlags flags of
        Err e ->
            ( (), sendError e )

        Ok ( deps, registry ) ->
            let
                reports =
                    deps
                        |> List.foldl
                            (\dep ->
                                let
                                    maybeVersions =
                                        Dict.get dep.name registry

                                    report =
                                        Maybe.map3 Report
                                            (Just dep.version |> Maybe.map versionToString)
                                            (maybeVersions |> Maybe.andThen (wantedVersion dep.version) |> Maybe.map versionToString)
                                            (maybeVersions |> Maybe.andThen List.head |> Maybe.map versionToString)
                                in
                                Dict.insert dep.name report
                            )
                            Dict.empty
                        |> Dict.filter
                            (\name maybeReport ->
                                case maybeReport of
                                    Nothing ->
                                        True

                                    Just report ->
                                        report.current /= report.latest
                            )
            in
            ( (), sendReports <| Dict.toList reports )


decodeFlags : Decode.Value -> Result String ( List Package, Registry )
decodeFlags flags =
    let
        rangeDecoder =
            Decode.string
                |> Decode.andThen
                    (\str ->
                        case List.head <| String.split " " str of
                            Nothing ->
                                Decode.fail "Incorrent dependency range format"

                            Just versionStr ->
                                case versionFromString versionStr of
                                    Nothing ->
                                        Decode.fail "Incorrect version format"

                                    Just version ->
                                        Decode.succeed version
                    )

        depsDecoder =
            Decode.keyValuePairs rangeDecoder
                |> Decode.at [ "dependencies" ]
                |> Decode.map (List.map (uncurry Package))

        decoder =
            Decode.map2 Tuple.pair
                (Decode.field "elmPackageJson" depsDecoder)
                (Decode.field "registry" registryDecoder)
    in
    case Decode.decodeValue decoder flags of
        Err _ ->
            Err "Your elm-package.json is corrupted."

        Ok decoded ->
            Ok decoded


versionFromString : String -> Maybe Version
versionFromString str =
    case String.split "." str of
        major :: minor :: patch :: [] ->
            Just <| Version major minor patch

        _ ->
            Nothing


versionToString : Version -> String
versionToString { major, minor, patch } =
    major ++ "." ++ minor ++ "." ++ patch


versionDecoder : Decode.Decoder Version
versionDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case versionFromString str of
                    Nothing ->
                        Decode.fail "Failed to decode version"

                    Just version ->
                        Decode.succeed version
            )


registryDecoder : Decode.Decoder Registry
registryDecoder =
    Decode.map Dict.fromList <|
        Decode.list <|
            Decode.map2 Tuple.pair
                (Decode.field "name" Decode.string)
                (Decode.field "versions" <| Decode.list versionDecoder)


wantedVersion : Version -> List Version -> Maybe Version
wantedVersion version versions =
    let
        safeVersions =
            versions
                |> List.filter (\{ major } -> major == version.major)
    in
    case safeVersions of
        [] ->
            Nothing

        nonEmptyVersions ->
            List.head nonEmptyVersions


uncurry : (a -> b -> c) -> ( a, b ) -> c
uncurry f ( a, b ) =
    f a b



---- PROGRAM ----


main : Program Decode.Value Model msg
main =
    Platform.worker
        { init = init
        , update = \msg model -> ( model, Cmd.none )
        , subscriptions = always Sub.none
        }


port sendReports : List ( String, Maybe Report ) -> Cmd msg


port sendError : String -> Cmd msg
