port module Main exposing (..)

import Dict
import Elm.Package
import Elm.Project
import Elm.Version
import Json.Decode as Decode
import Platform



---- MODEL


type alias Model =
    ()


type alias Registry =
    Dict.Dict String (List Elm.Version.Version)


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
            ( (), sendReports <| collectReports deps registry )


decodeFlags : Decode.Value -> Result String ( Elm.Project.Deps Elm.Version.Version, Registry )
decodeFlags flags =
    let
        decoder =
            Decode.map2 (\a b -> ( a, b ))
                (Decode.field "elmPackageJson" Elm.Project.decoder)
                (Decode.field "registry" <| Decode.dict (Decode.list Elm.Version.decoder))
    in
    case Decode.decodeValue decoder flags of
        Err e ->
            Err "Your elm.json is corrupted"

        Ok ( Elm.Project.Package _, _ ) ->
            Err "TODO: packages not supported"

        Ok ( Elm.Project.Application { deps, testDeps }, registry ) ->
            Ok ( deps ++ testDeps, registry )


collectReports : Elm.Project.Deps Elm.Version.Version -> Registry -> List ( String, Report )
collectReports deps registry =
    deps
        |> List.foldl
            (\( name, version ) ->
                let
                    availableVersions =
                        registry
                            |> Dict.get (Elm.Package.toString name)
                            |> Maybe.withDefault [ version ]
                in
                Dict.insert (Elm.Package.toString name)
                    { current = Elm.Version.toString version
                    , wanted =
                        availableVersions
                            |> wantedVersion version
                            |> Elm.Version.toString
                    , latest =
                        availableVersions
                            |> List.reverse
                            |> List.head
                            |> Maybe.withDefault version
                            |> Elm.Version.toString
                    }
            )
            Dict.empty
        |> Dict.toList


wantedVersion : Elm.Version.Version -> List Elm.Version.Version -> Elm.Version.Version
wantedVersion version versions =
    let
        ( major, _, _ ) =
            Elm.Version.toTuple version
    in
    versions
        |> List.filter
            (\checkedVersion ->
                let
                    ( checkedMajor, _, _ ) =
                        Elm.Version.toTuple checkedVersion
                in
                major == checkedMajor
            )
        |> List.reverse
        |> List.head
        |> Maybe.withDefault version



---- PROGRAM


main : Program Decode.Value Model msg
main =
    Platform.worker
        { init = init
        , update = \msg model -> ( model, Cmd.none )
        , subscriptions = always Sub.none
        }


port sendReports : List ( String, Report ) -> Cmd msg


port sendError : String -> Cmd msg
