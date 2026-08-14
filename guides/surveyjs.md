# SurveyJS Compatibility

DynamicForm can create a form from data. One way to define form data is with JSON.

DynamicForm's data format is compatible with
[SurveyJS form definitions](https://surveyjs.io/form-library/documentation):
JSON produced for SurveyJS — by hand, by a WYSIWYG builder, or exported from
SurveyJS Creator — decodes the JSON and renders with
DynamicForm's own LiveView components. The compatibility is with the
definition format, not the SurveyJS JavaScript runtime: rendering,
validation, and submission are all server-side using Phoenix LiveView
components and Ecto.

Pass SurveyJS JSON directly into the form component:

```json
{
  "title": "Contact Form",
  "elements": [
    {"type": "text", "name": "name", "inputType": "text"},
    {"type": "text", "name": "email", "inputType": "email"}
  ]
}
```

```heex
<DynamicForm.form id="contact-form" json={@json} />
```

## Supported

DynamicForm does not attempt to implement the entire SurveyJS functionality.
Instead, it targets the most important and useful parts for building dynamic forms.

### Question types

| SurveyJS type | Renders as | Notes |
|---|---|---|
| `text` | `<input>` | `inputType` passes through (`email`, `number`, ...); `number` casts to decimal |
| `comment` | `<textarea>` | |
| `dropdown` | `<select>` | |
| `radiogroup` | Radio buttons | |
| `checkbox` | Checkbox group | Array-valued |
| `tagbox` | Multi-select | Array-valued |
| `boolean` | Single checkbox | |
| `rating` | Numeric radio row | `rateMin`/`rateMax`/`rateStep` (defaults 1–5) |
| `file` | Direct-to-cloud upload | Configured via `metadata` (a DynamicForm extension) — see [Usage: File uploads](usage.md#file-uploads) |
| `paneldynamic` | Repeating child form with add/remove | Value is a list of maps; each entry validates against `templateElements` with its own changeset — see the [Nested Forms guide](nested-forms.md) |

### Element types

| SurveyJS type | Renders as | Notes |
|---|---|---|
| `html` | Raw HTML block | |
| `panel` | Titled container | Nesting supported |
| `image` | `<img>` | `imageLink`, `imageWidth`, `imageHeight`, `imageFit` |

### Question properties

`name`, `type`, `inputType`, `title`, `description`, `placeholder`,
`defaultValue`, `choices`, `validators`, `isRequired`, `requiredIf`,
`readOnly`, `enableIf`, `visibleIf`, and `rateMin`/`rateMax`/`rateStep`.

For `paneldynamic`: `templateElements` (alias `questions`), `templateTitle`
(with `{panelIndex}`), `panelCount`, `minPanelCount`, `maxPanelCount`,
`allowAddPanel`, `allowRemovePanel`, `addPanelText` (alias `panelAddText`),
`removePanelText` (alias `panelRemoveText`), `noEntriesText`,
`confirmDelete`, `confirmDeleteText`, `keyName`, `keyDuplicationError`, and
`defaultPanelValue`. Template expressions support the `{panel.field}`
scope prefix. Not supported: `displayMode`/`renderMode` variants other than
the default list (`carousel`, `tab`), `templateVisibleIf`,
`{parentPanel.*}`/`{prevPanel.*}` references, and file uploads inside
templates.

`choices` accepts plain strings (`["a", "b"]`), value/text objects
(`[{"value": "v", "text": "Label"}]`), and integers.

### Validators

| SurveyJS validator | Fields |
|---|---|
| `text` | `minLength`, `maxLength` |
| `numeric` | `minValue`, `maxValue` |
| `email` | — |
| `regex` | `regex` |

Each accepts a custom error message via `text`. All validation runs
server-side through an Ecto changeset.

### Conditional expressions

`visibleIf`, `requiredIf`, and `enableIf` support: `=`, `==`, `<>`, `!=`,
`>`, `<`, `>=`, `<=`, `empty`, `notempty`, `contains`, `notcontains`,
`anyof`, `allof`, `noneof`, combined with `and`, `or`, and parentheses.
Field references use braces (`{field}`); literals are `'strings'`, numbers,
booleans, and `['lists']`. Hidden required questions are excluded from
validation automatically.

### Form-level

`title` and `description` decode onto the instance. Multi-page definitions
(`pages`) are supported by flattening: all pages merge into a single form,
with page titles preserved as headings.

## Not Supported

Not exhaustive — the major and common SurveyJS features DynamicForm does not
implement. Unknown question and element types don't fail the form: they are
skipped (nothing renders — obvious in testing, not broken-looking in
production) and the rest of the form works normally. Applications can also
register their own types — see
[Usage: Custom field types](usage.md#custom-field-types).

| Feature | Notes |
|---|---|
| Matrix types (`matrix`, `matrixdropdown`, `matrixdynamic`) | `matrixdynamic` is a natural follow-up — it shares `paneldynamic`'s data shape and validation machinery, rendered as a table |
| `multipletext` | Multiple inputs in one question |
| `signaturepad`, `imagepicker`, `ranking`, `slider` | Specialized input widgets |
| `expression` questions, calculated values, triggers | No expression *evaluation* beyond the conditional operators above (`setValueIf`, `runexpression`, quiz scoring, ...) |
| `expression` and `answercount` validators | Use [`on_change`](lifecycle.md#optional-enhancement-on_change) for cross-field validation |
| Multi-page navigation | Pages are flattened into one form — no page-by-page navigation, progress bar, or per-page validation |
| Choice loading (`choicesByUrl`, lazy loading) | Provide choices in the definition |
| `showOtherItem` / `showNoneItem` / `showSelectAllItem` | Choice extras |
| Input masks | |
| Localization objects | Multi-locale strings (`{"default": ..., "de": ...}`) aren't decoded; error messages translate via [Gettext](usage.md#internationalization) instead |
| SurveyJS themes and CSS customization | Styling is Tailwind via DynamicForm's components |

## DynamicForm extensions

Beyond the SurveyJS format, definitions can carry:

- **`metadata`** — per-question extension point: file upload configuration,
  `"style"` (`"horizontal"`/`"vertical"`) for radiogroup/checkbox layout.
- **`generateIds`** — on by default for `paneldynamic`: every entry carries a
  stable `dynamic_form_id`, copied from the entry's `id` when the data came
  from a stored record. See
  [Nested forms: Entry ids](nested-forms.md#entry-ids).
- **Declarative mode** — the same instances can be defined with `<:field>`
  slots in HEEx, including custom markup via slot bodies (in-memory only;
  dropped on JSON encoding). See [Usage: Defining forms](usage.md#defining-forms).
