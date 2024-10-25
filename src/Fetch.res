module Response = {
  type t

  @send
  external json: t => Js.Promise.t<Js.Json.t> = "json"

  @send
  external text: t => Js.Promise.t<string> = "text"

  @get
  external ok: t => bool = "ok"

  @get
  external status: t => int = "status"

  @get
  external statusText: t => string = "statusText"
}

type method =
  | GET
  | PATCH

let methodToString = (m: method): string =>
  switch m {
  | GET => "GET"
  | PATCH => "PATCH"
  }

// add body and method for PATCH function
type options = {
  headers: Js.Dict.t<string>,
  body: option<string>,
  method: string,
}

@val
external fetch: (string, options) => Js.Promise.t<Response.t> = "fetch"

let fetchJson = (~headers=Js.Dict.empty(), url: string): Js.Promise.t<Js.Json.t> =>
  fetch(url, {headers: headers, method: methodToString(GET), body: None}) |> Js.Promise.then_(res =>
    if !Response.ok(res) {
      res->Response.text->Js.Promise.then_(text => {
        let msg = `${res->Response.status->Js.Int.toString} ${res->Response.statusText}: ${text}`
        Js.Exn.raiseError(msg)
      }, _)
    } else {
      res->Response.json
    }
  )

// PATCH function using fetch to use to send data to the backend
let fetchPatch = (~headers=Js.Dict.empty(), url: string, body: string): Js.Promise.t<Js.Json.t> => {
  fetch(
    url,
    {headers: headers, method: methodToString(PATCH), body: Some(body)},
  ) |> Js.Promise.then_(res =>
    if !Response.ok(res) {
      res->Response.text->Js.Promise.then_(text => {
        let msg = `${res->Response.status->Js.Int.toString} ${res->Response.statusText}: ${text}`
        Js.Exn.raiseError(msg)
      }, _)
    } else {
      res->Response.json
    }
  )
}
