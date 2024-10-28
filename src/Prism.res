%raw(`require("./Prism.css")`)

// the box model type coordinates for the top, right, bottom, and left properties used for margins and paddings
type boxModel = {
  top: string,
  right: string,
  bottom: string,
  left: string,
}

module AutoDefaultComponent = {
  @react.component
  let make = (~handleClick) => {
    <div className="AutoColor Clickable" onClick={handleClick}> {React.string("auto")} </div>
  }
}

/*
  EditableAuto component that manages an editable input within a box model.
  This component is implemented to handle both margins and paddings depending on the 
  BoxContainer context as the have the same data structure. It takes an `onUpdate` 
  function to send data to the backend when the input loses focus. The `data` parameter
  is used to initialize the component with data fetched from the backend.

  props:
  - onUpdate: a function that takes a string and returns unit. This is called 
    whenever the input value changes and loses focus to actively update the 
    component props data.
  - data: a string representing the initial value fetched from the backend. 
    It can be "auto", a string representation of the current value, or None, 
    indicating an uninitialized state.
 */
module EditableAuto = {
  @react.component
  let make = (~onUpdate: string => unit, ~data: string) => {
    let (value, setValue) = React.useState(_ => data)
    let (isEditing, setIsEditing) = React.useState(_ => false)

    // get the updated value of the editable component
    React.useEffect1(() => {
      setValue(_ => data)
      None
    }, [data])

    // handle making the component editable to render an input instead of div
    let handleClick = (_event: ReactEvent.Mouse.t) => setIsEditing(_ => true)

    // handle losing focus on the editable component and send data to backend on losing focus
    let handleBlur = _event => {
      setIsEditing(_ => false)
      if value != data {
        onUpdate(value)
      }
      if Js.String2.length(value) == 0 {
        setValue(_ => "auto")
      }
    }

    // handle the change event on the editable component to set the user input
    let handleChange = event => {
      let target = event->ReactEvent.Form.target
      let newValue = target["value"]
      setValue(_ => newValue)
    }

    <div>
      {switch isEditing {
      | true =>
        <div className="CellContainer">
          <input
            className="EditableInput"
            // check if a value exists, otherwise default to "auto"
            value={value}
            onChange={handleChange}
            onBlur={handleBlur}
            autoFocus=true
          />
          <div className="Metric"> {React.string("px")} </div>
        </div>
      | false =>
        // if not editing, show the value with metric in the box model
        switch value {
        | "auto" => <AutoDefaultComponent handleClick />
        | _ =>
          <div className="Clickable Changed" onClick={handleClick}>
            {React.string(value)} {React.string("px")}
          </div>
        }
      }}
    </div>
  }
}

/*
  box container component to render the margins box model and the paddings box model
  the margins are in the outer box separated vertically and horizontally
  the paddings are in the inner box (children) separated vertically and horizontally

  in my opinion, this is good as we can visualize that they are just 2 boxes, and one
  is wrapping the other (the margins box in this case). Making the component reusable
  and easy to use for both margins and paddings
 */
module BoxContainer = {
  @react.component
  let make = (
    ~children: React.element,
    ~isChild=false,
    ~paddings: option<boxModel>,
    ~margins: option<boxModel>,
    ~onMarginChange: (string, string) => unit,
    ~onPaddingChange: (string, string) => unit,
  ) => {
    // checks if the rendered component is the padding box or the margins box to know which one to update
    let data = isChild ? paddings : margins
    let onUpdate = isChild ? onPaddingChange : onMarginChange
    let {top, right, bottom, left} = switch data {
    | Some(d) => d
    | None => {top: "auto", right: "auto", bottom: "auto", left: "auto"}
    }

    <div className="VerticalSpacing">
      <EditableAuto onUpdate={newValue => onUpdate(newValue, "top")} data={top} />
      <div className="BoxContainer">
        <EditableAuto onUpdate={newValue => onUpdate(newValue, "left")} data={left} />
        children
        <EditableAuto onUpdate={newValue => onUpdate(newValue, "right")} data={right} />
      </div>
      <EditableAuto onUpdate={newValue => onUpdate(newValue, "bottom")} data={bottom} />
    </div>
  }
}

// updating the component properties by sending the data using fetch patch function
let updateComponentProperties = (id: string, properties: Js.Dict.t<Js.Json.t>): unit => {
  let url = `http://localhost:12346/components/${id}/properties`
  let headers = Js.Dict.empty()
  Js.Dict.set(headers, "Content-Type", "application/json")

  let body = Js.Json.stringify(Js.Json.object_(properties))

  Fetch.fetchPatch(~headers, url, body)
  |> Js.Promise.then_(res => {
    Js.Promise.resolve(res)
  })
  |> ignore
}

// Margings & Padding
module MarginsAndPadding = {
  @react.component
  let make = () => {
    // initialize margins and paddings for a component as we would have the props data from the component be fetched from the backend
    // then would be defaulted to auto if None
    let (margins: option<boxModel>, setMargins) = React.useState(_ => None)
    let (paddings: option<boxModel>, setPaddings) = React.useState(_ => None)

    // fetch the component props value from the backend
    React.useEffect1(() => {
      Fetch.fetchJson(`http://localhost:12346/components/1/properties`)
      |> Js.Promise.then_(data => {
        let response: Js.Dict.t<string> = Obj.magic(data)

        let getSpacingValues = (prefix: string, res: Js.Dict.t<string>) => Some({
          top: Js.Dict.get(res, prefix ++ "_top")->Belt.Option.getWithDefault("auto"),
          right: Js.Dict.get(res, prefix ++ "_right")->Belt.Option.getWithDefault("auto"),
          bottom: Js.Dict.get(res, prefix ++ "_bottom")->Belt.Option.getWithDefault("auto"),
          left: Js.Dict.get(res, prefix ++ "_left")->Belt.Option.getWithDefault("auto"),
        })

        // set margins and paddings using the first element of the response array
        setMargins(_ => getSpacingValues("margin", response))
        setPaddings(_ => getSpacingValues("padding", response))

        Js.Promise.resolve(None)
      })
      |> ignore

      None
    }, [])

    // reusable function to update the box model with the new value depending on the side and isMargin
    let updateBoxModel = (newValue: string, side: string, isMargin: bool) => {
      let updateFn = isMargin ? setMargins : setPaddings
      let prefix = isMargin ? "margin" : "padding"

      updateFn(_ => {
        let properties = Js.Dict.empty()
        Js.Dict.set(properties, prefix ++ "_" ++ side, Js.Json.string(newValue))

        // send the updated properties to the backend for the component of id = 1 (for test purposes)
        updateComponentProperties("1", properties)

        None
      })
    }

    // functions to update margin and padding, respectively
    let onMarginChange = (newValue: string, side: string) => updateBoxModel(newValue, side, true)
    let onPaddingChange = (newValue: string, side: string) => updateBoxModel(newValue, side, false)

    <BoxContainer paddings margins onMarginChange onPaddingChange>
      <div className="Box">
        <BoxContainer paddings margins isChild=true onMarginChange onPaddingChange>
          <div className="HorizontalSpacing" />
        </BoxContainer>
      </div>
    </BoxContainer>
  }
}
