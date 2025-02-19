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

type method = [#GET | #PATCH]

// add body and method for PATCH function
type options = {
  headers: Js.Dict.t<string>,
  // optional as the GET request wouldn't have a body
  body: option<string>,
  method: method,
}

@val
external fetch: (string, options) => Js.Promise.t<Response.t> = "fetch"

let fetchWithMethod = (
  ~headers=Js.Dict.empty(),
  url: string,
  ~method: method,
  ~body: option<string>,
): Js.Promise.t<Js.Json.t> =>
  fetch(url, {headers: headers, method: method, body: body}) |> Js.Promise.then_(res =>
    if !Response.ok(res) {
      res->Response.text->Js.Promise.then_(text => {
        let msg = `${res->Response.status->Js.Int.toString} ${res->Response.statusText}: ${text}`
        Js.Exn.raiseError(msg)
      }, _)
    } else {
      res->Response.json
    }
  )

let fetchJson = (~headers=Js.Dict.empty(), url: string): Js.Promise.t<Js.Json.t> =>
  fetchWithMethod(~headers, url, ~method=#GET, ~body=None)

let fetchPatch = (~headers=Js.Dict.empty(), url: string, body: string): Js.Promise.t<Js.Json.t> =>
  fetchWithMethod(~headers, url, ~method=#PATCH, ~body=Some(body))
