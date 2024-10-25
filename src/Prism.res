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
  BoxContainer context. It takes an `onUpdate` function to send data to the backend 
  when the input loses focus. The `data` parameter is used to initialize the 
  component with data fetched from the backend.

  props:
  - onUpdate: a function that takes a string and returns unit. This is called 
    whenever the input value changes and loses focus.
  - data: a string representing the initial value fetched from the backend. 
    It can be "auto", a string representation of the current value, or None, 
    indicating an uninitialized state.
 */
module EditableAuto = {
  @react.component
  let make = (~onUpdate: string => unit, ~data: string) => {
    let (value, setValue) = React.useState(_ => Some(data))
    let (isEditing, setIsEditing) = React.useState(_ => false)

    // get the updated value of the editable component
    React.useEffect1(() => {
      if data == "" {
        setValue(_ => Some("auto"))
      } else {
        setValue(_ => Some(data))
      }
      None
    }, [data])

    // handle making the component editable
    let handleClick = (_event: ReactEvent.Mouse.t) => setIsEditing(_ => true)
    // handle losing focus on the editable component and send data to backend on losing focus
    let handleBlur = _event => {
      setIsEditing(_ => false)
      switch value {
      | Some(val) => {
          if val != data {
            onUpdate(val)
          }
          if Js.String2.length(val) == 0 {
            setValue(_ => Some("auto"))
          }
        }
      | None => setValue(_ => Some("auto"))
      }
    }
    // handle the change event on the editable component
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
            value={switch value {
            | Some(val) => val
            | None => "auto"
            }}
            onChange={handleChange}
            onBlur={handleBlur}
            autoFocus=true
          />
          <div className="Metric"> {React.string("px")} </div>
        </div>
      | false =>
        // if not editing, show the value with metric in the box model
        switch value {
        | Some("auto") => <AutoDefaultComponent handleClick />
        | Some(val) =>
          <div className="Clickable Changed" onClick={handleClick}>
            {React.string(val)} {React.string("px")}
          </div>
        | None => <AutoDefaultComponent handleClick />
        }
      }}
    </div>
  }
}

/*
  box container component to render the margins box model and the paddings box model
  the margins are in the outer box separated vertically and horizontally
  the paddings are in the inner box (children) separated vertically and horizontally
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
    // checks if the rendered component is the padding box or the margins box
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
let updateComponentProperties = (id: string, properties: Js.Dict.t<Js.Json.t>): Js.Promise.t<
  Js.Json.t,
> => {
  let url = `http://localhost:12346/components/${id}/properties`
  let headers = Js.Dict.empty()
  Js.Dict.set(headers, "Content-Type", "application/json")

  let body = Js.Json.stringify(Js.Json.object_(properties))

  Fetch.fetchPatch(~headers, url, body)
}

// Margings & Padding
module MarginsAndPadding = {
  @react.component
  let make = () => {
    // initialize margins and paddings for a component
    let (margins: option<boxModel>, setMargins) = React.useState(_ => None)
    let (paddings: option<boxModel>, setPaddings) = React.useState(_ => None)

    // fetch the component props value from the backend
    React.useEffect1(() => {
      Fetch.fetchJson(`http://localhost:12346/components/1/properties`)
      |> Js.Promise.then_(data => {
        let response = Obj.magic(data)

        // set the margins with the fetched data
        setMargins(_ => {
          Some({
            top: response[0]["margin_top"],
            right: response[0]["margin_right"],
            bottom: response[0]["margin_bottom"],
            left: response[0]["margin_left"],
          })
        })

        // set the paddings with the fetched data
        setPaddings(_ => {
          Some({
            top: response[0]["padding_top"],
            right: response[0]["padding_right"],
            bottom: response[0]["padding_bottom"],
            left: response[0]["padding_left"],
          })
        })

        Js.Promise.resolve(None)
      })
      |> ignore

      None
    }, [])

    // generic function to update the box model with the new value depending on the side and isMargin
    let updateBoxModel = (newValue: string, side: string, isMargin: bool) => {
      let updateFn = isMargin ? setMargins : setPaddings

      updateFn(currentBoxModel => {
        let currentValues = switch currentBoxModel {
        | Some(m) => m
        | None => {top: "auto", right: "auto", bottom: "auto", left: "auto"}
        }

        let updatedValues: boxModel = switch side {
        | "top" => {...currentValues, top: newValue}
        | "right" => {...currentValues, right: newValue}
        | "bottom" => {...currentValues, bottom: newValue}
        | "left" => {...currentValues, left: newValue}
        | _ => currentValues
        }

        let properties = Js.Dict.empty()
        if isMargin {
          Js.Dict.set(properties, "margin_top", Js.Json.string(updatedValues.top))
          Js.Dict.set(properties, "margin_right", Js.Json.string(updatedValues.right))
          Js.Dict.set(properties, "margin_bottom", Js.Json.string(updatedValues.bottom))
          Js.Dict.set(properties, "margin_left", Js.Json.string(updatedValues.left))
        } else {
          Js.Dict.set(properties, "padding_top", Js.Json.string(updatedValues.top))
          Js.Dict.set(properties, "padding_right", Js.Json.string(updatedValues.right))
          Js.Dict.set(properties, "padding_bottom", Js.Json.string(updatedValues.bottom))
          Js.Dict.set(properties, "padding_left", Js.Json.string(updatedValues.left))
        }

        // send the updated properties to the backend for the component of id = 1 (for test purposes)
        updateComponentProperties("1", properties)
        |> Js.Promise.then_(res => {
          res->Js.log
          Js.Promise.resolve(updatedValues)
        })
        |> ignore

        Some(updatedValues)
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
