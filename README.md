# DynamicForm

A library for creating dynamic forms with full backend validation using
changesets and calls to backend functions in Elixir Phoenix. Also supports
building forms through a WYSIWYG interface.

This library enables users to build forms dynamically through a visual interface,
then render those forms using standard Phoenix LiveView patterns with robust
validation and backend integration.

## SurveyJS-Compatible Format

Form definitions use [SurveyJS-compatible JSON](https://surveyjs.io/form-library/documentation):

```elixir
instance = DynamicForm.Instance.decode!(~S({
  "title": "Contact Form",
  "elements": [
    {
      "type": "text",
      "name": "email",
      "inputType": "email",
      "title": "Email Address",
      "isRequired": true,
      "validators": [{"type": "email"}]
    },
    {
      "type": "dropdown",
      "name": "subject",
      "title": "Subject",
      "choices": [{"value": "support", "text": "Support"}]
    },
    {
      "type": "comment",
      "name": "details",
      "title": "Details",
      "visibleIf": "{subject} = 'support'"
    }
  ]
}))
```

### Supported question types

| Type | Renders as | Notes |
|------|-----------|-------|
| `text` | `<input>` | `inputType` passes through (`email`, `number`, ...) |
| `comment` | `<textarea>` | |
| `dropdown` | `<select>` | |
| `radiogroup` | Radio buttons | `metadata.style`: `vertical`/`horizontal` |
| `checkbox` | Checkbox group | Array-valued |
| `tagbox` | Multi-select | Array-valued |
| `boolean` | Single checkbox | |
| `rating` | Numeric radio row | `rateMin`/`rateMax`/`rateStep` (default 1–5) |
| `file` | Direct upload | Presigner configured via `metadata` |

Element types: `html`, `panel` (nesting container), `image`.

### Conditional logic

`visibleIf`, `requiredIf`, and `enableIf` accept SurveyJS expressions:

```
{field} = 'value'        {field} notempty         {field} > 100
{a} = 'x' and {b} empty  {tags} anyof ['a', 'b']  {list} contains 'item'
```

Supported operators: `=`, `==`, `<>`, `!=`, `>`, `<`, `>=`, `<=`, `empty`,
`notempty`, `contains`, `notcontains`, `anyof`, `allof`, `noneof`, combined
with `and`, `or`, and parentheses. Hidden required questions are excluded
from validation automatically.

### Validators

`text` (`minLength`/`maxLength`), `numeric` (`minValue`/`maxValue`), `email`,
and `regex`. Each accepts a custom error message via `text`.

Not supported (rendered as a visible fallback box): matrix types,
`paneldynamic`, `multipletext`, `signaturepad`, `imagepicker`, `ranking`,
`slider`, `expression`. Multi-page definitions are flattened into a single
form.

## Installation

When using as a path dependency in your Phoenix app:

```elixir
def deps do
  [
    {:dynamic_form, path: "../"}
  ]
end
```
