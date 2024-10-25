%raw(`require("./PropertiesPanel.css")`)

module Collapsible = {
  @react.component
  let make = (~title, ~children) => {
    let (collapsed, toggle) = React.useState(() => false)

    <section className="Collapsible">
      <button className="Collapsible-button" onClick={_e => toggle(_ => !collapsed)}>
        <span> {React.string(title)} </span> <span> {React.string(collapsed ? "+" : "-")} </span>
      </button>
      {collapsed ? React.null : <div className="Collapsible-content"> {children} </div>}
    </section>
  }
}

// This component provides a simplified example of fetching JSON data from
// the backend and rendering it on the screen.
module ViewExamples = {
  // Type of the data returned by the /components endpoint
  type component = {
    id: int,
    name: string,
  }

  @react.component
  let make = () => {
    let (components: option<array<component>>, setComponents) = React.useState(_ => None)

    React.useEffect1(() => {
      // Fetch the data from /examples and set the state when the promise resolves
      Fetch.fetchJson(`http://localhost:12346/components`)
      |> Js.Promise.then_(componentsJson => {
        Js.log(componentsJson)
        // NOTE: this uses an unsafe type cast, as safely parsing JSON in rescript is somewhat advanced.
        Js.Promise.resolve(setComponents(_ => Some(Obj.magic(componentsJson))))
      })
      // The "ignore" function is necessary because each statement is expected to return `unit` type, but Js.Promise.then return a Promise type.
      |> ignore
      None
    }, [setComponents])

    <div>
      {switch components {
      | None => React.string("Loading components....")
      | Some(components) =>
        components
        ->Js.Array2.map(component =>
          React.string(`Int: ${component.id->Js.Int.toString}, Str: ${component.name}`)
        )
        ->React.array
      }}
    </div>
  }
}

@genType @genType.as("PropertiesPanel") @react.component
let make = () => {
  // import Prism component (not sure if this is the best way to do it, but the documentation says it is allowed)
  open Prism
  <aside className="PropertiesPanel">
    <Collapsible title="Components"> <ViewExamples /> </Collapsible>
    // the finished part of the project!
    <Collapsible title="Margins & Padding"> <MarginsAndPadding /> </Collapsible>
    <Collapsible title="Size"> <span> {React.string("example")} </span> </Collapsible>
  </aside>
}
