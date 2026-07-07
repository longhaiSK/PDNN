// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))



#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  let has-title-block = title != none or (authors != none and authors != ()) or date != none or abstract != none
  if has-title-block {
    place(
      top,
      float: true,
      scope: "parent",
      clearance: 4mm,
      block(below: 1em, width: 100%)[

        #if title != none {
          align(center, block(inset: 2em)[
            #set par(leading: heading-line-height) if heading-line-height != none
            #set text(font: heading-family) if heading-family != none
            #set text(weight: heading-weight)
            #set text(style: heading-style) if heading-style != "normal"
            #set text(fill: heading-color) if heading-color != black

            #text(size: title-size)[#title #if thanks != none {
              footnote(thanks, numbering: "*")
              counter(footnote).update(n => n - 1)
            }]
            #(if subtitle != none {
              parbreak()
              text(size: subtitle-size)[#subtitle]
            })
          ])
        }

        #if authors != none and authors != () {
          let count = authors.len()
          let ncols = calc.min(count, 3)
          grid(
            columns: (1fr,) * ncols,
            row-gutter: 1.5em,
            ..authors.map(author =>
                align(center)[
                  #author.name \
                  #author.affiliation \
                  #author.email
                ]
            )
          )
        }

        #if date != none {
          align(center)[#block(inset: 1em)[
            #date
          ]]
        }

        #if abstract != none {
          block(inset: 2em)[
          #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
          ]
        }
      ]
    )
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)

#show: doc => article(
  title: [Project Guide: Predicting Parkinson's Disease using Microbiome Data],
  authors: (
    ( name: [Project Instructions],
      affiliation: [],
      email: [] ),
    ),
  toc_title: [Table of contents],
  toc_depth: 3,
  doc,
)

= Welcome to the Project!
<welcome-to-the-project>
In this project, your team of three will work at the intersection of biology and artificial intelligence. Your goal is to train a computer program to predict whether a person has Parkinson's Disease (PD) just by looking at the bacteria living in their stomach.

If you don't know anything about biology or coding yet---don't worry! This guide will break down the science, the data, the coding, and how to write up your final report.

#horizontalrule

= The Biology: What is the Microbiome?
<the-biology-what-is-the-microbiome>
Imagine your gut is a bustling city. The "citizens" of this city are trillions of tiny microorganisms, mostly bacteria. We call this community the #strong[gut microbiome].

In a healthy person, there is a good, peaceful balance of different bacterial families. But researchers have discovered that in people with Parkinson's Disease (a condition that affects the brain and nervous system), the population of this gut city changes. Some "good" bacteria families disappear, and other families multiply rapidly.

When scientists sequence DNA from stool samples, they are basically doing a census of this city. The data you will be looking at is actually just a giant spreadsheet: \* Every #strong[row] is a different patient. \* Every #strong[column] is a different type of bacteria. \* The #strong[numbers] in the cells show exactly how many of that specific bacteria were found in that patient's gut.

#horizontalrule

= The Data: The Journey from Raw Counts to Hidden Patterns
<the-data-the-journey-from-raw-counts-to-hidden-patterns>
When scientists run a DNA sequencer to do a "census" of the gut, it doesn't count every single bacteria perfectly. It grabs a random sample. We call the total number of bacteria successfully counted in a sample the #strong[Total Reads].

Because every stool sample is a little different, the sequencer might capture 40,000 bacteria for Patient 1, but only 15,000 for Patient 8.

Let's generate a realistic synthetic dataset of 100 patients (50 with Parkinson's, 50 Healthy). To show you how complex this gets, we will look at #strong[6 different bacterial families].

== Step 1: The Raw Data
<step-1-the-raw-data>
First, we will generate the raw counts and take a look at what comes straight out of the sequencing machine.

#Skylighting(([#ImportTok("import");#NormalTok(" pandas ");#ImportTok("as");#NormalTok(" pd");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("import");#NormalTok(" seaborn ");#ImportTok("as");#NormalTok(" sns");],
[#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("from");#NormalTok(" itables ");#ImportTok("import");#NormalTok(" init_notebook_mode, show");],
[],
[#CommentTok("# Initialize itables for interactive spreadsheets");],
[#NormalTok("init_notebook_mode(all_interactive");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],
[#NormalTok("np.random.seed(");#DecValTok("42");#NormalTok(")");],
[#NormalTok("n_pd ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");],
[#NormalTok("n_healthy ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");],
[],
[#CommentTok("# Total Reads (Let's say PD samples just happened to get sequenced deeper)");],
[#NormalTok("reads_pd ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("40000");#NormalTok(", ");#DecValTok("5000");#NormalTok(", n_pd).astype(");#BuiltInTok("int");#NormalTok(")");],
[#NormalTok("reads_healthy ");#OperatorTok("=");#NormalTok(" np.random.normal(");#DecValTok("15000");#NormalTok(", ");#DecValTok("3000");#NormalTok(", n_healthy).astype(");#BuiltInTok("int");#NormalTok(")");],
[#NormalTok("total_reads ");#OperatorTok("=");#NormalTok(" np.concatenate([reads_pd, reads_healthy])");],
[],
[#CommentTok("# Generate 6 Bacteria Columns (Underlying Proportions)");],
[#CommentTok("# PAIR 1 (The Hidden Rule): Bifido & Lacto (Negative correlation)");],
[#NormalTok("bifido_pd ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#FloatTok("0.02");#NormalTok(", ");#FloatTok("0.13");#NormalTok(", n_pd)");],
[#NormalTok("lacto_pd ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.15");#NormalTok(" ");#OperatorTok("-");#NormalTok(" bifido_pd ");#OperatorTok("+");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#FloatTok("0.005");#NormalTok(", n_pd) ");],
[#NormalTok("bifido_healthy ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.30");#NormalTok(", n_healthy)");],
[#NormalTok("lacto_healthy ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.35");#NormalTok(" ");#OperatorTok("-");#NormalTok(" bifido_healthy ");#OperatorTok("+");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#FloatTok("0.005");#NormalTok(", n_healthy)");],
[],
[#CommentTok("# PAIR 2 (Distraction): Bact & Prev (No real difference between groups)");],
[#NormalTok("bact_pd ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#FloatTok("0.10");#NormalTok(", ");#FloatTok("0.30");#NormalTok(", n_pd)");],
[#NormalTok("prev_pd ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.40");#NormalTok(" ");#OperatorTok("-");#NormalTok(" bact_pd ");#OperatorTok("+");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#FloatTok("0.01");#NormalTok(", n_pd)");],
[#NormalTok("bact_healthy ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#FloatTok("0.10");#NormalTok(", ");#FloatTok("0.30");#NormalTok(", n_healthy)");],
[#NormalTok("prev_healthy ");#OperatorTok("=");#NormalTok(" ");#FloatTok("0.40");#NormalTok(" ");#OperatorTok("-");#NormalTok(" bact_healthy ");#OperatorTok("+");#NormalTok(" np.random.normal(");#DecValTok("0");#NormalTok(", ");#FloatTok("0.01");#NormalTok(", n_healthy)");],
[],
[#CommentTok("# PAIR 3 (Random Noise): Esch & Kleb (Fills the rest of the gut space)");],
[#NormalTok("esch_pd ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.15");#NormalTok(", n_pd)");],
[#NormalTok("kleb_pd ");#OperatorTok("=");#NormalTok(" ");#FloatTok("1.0");#NormalTok(" ");#OperatorTok("-");#NormalTok(" (bifido_pd ");#OperatorTok("+");#NormalTok(" lacto_pd ");#OperatorTok("+");#NormalTok(" bact_pd ");#OperatorTok("+");#NormalTok(" prev_pd ");#OperatorTok("+");#NormalTok(" esch_pd)");],
[#NormalTok("esch_healthy ");#OperatorTok("=");#NormalTok(" np.random.uniform(");#FloatTok("0.05");#NormalTok(", ");#FloatTok("0.15");#NormalTok(", n_healthy)");],
[#NormalTok("kleb_healthy ");#OperatorTok("=");#NormalTok(" ");#FloatTok("1.0");#NormalTok(" ");#OperatorTok("-");#NormalTok(" (bifido_healthy ");#OperatorTok("+");#NormalTok(" lacto_healthy ");#OperatorTok("+");#NormalTok(" bact_healthy ");#OperatorTok("+");#NormalTok(" prev_healthy ");#OperatorTok("+");#NormalTok(" esch_healthy)");],
[],
[#CommentTok("# Convert underlying proportions to Raw Counts");],
[#NormalTok("df_raw ");#OperatorTok("=");#NormalTok(" pd.DataFrame({");],
[#NormalTok("    ");#StringTok("\"Patient_ID\"");#NormalTok(": [");#SpecialStringTok("f\"PD_");#SpecialCharTok("{");#BuiltInTok("str");#NormalTok("(i)");#SpecialCharTok(".");#NormalTok("zfill(");#DecValTok("3");#NormalTok(")");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(" ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1");#NormalTok(", n_pd");#OperatorTok("+");#DecValTok("1");#NormalTok(")] ");#OperatorTok("+");#NormalTok(" [");#SpecialStringTok("f\"Healthy_");#SpecialCharTok("{");#BuiltInTok("str");#NormalTok("(i)");#SpecialCharTok(".");#NormalTok("zfill(");#DecValTok("3");#NormalTok(")");#SpecialCharTok("}");#SpecialStringTok("\"");#NormalTok(" ");#ControlFlowTok("for");#NormalTok(" i ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("range");#NormalTok("(");#DecValTok("1");#NormalTok(", n_healthy");#OperatorTok("+");#DecValTok("1");#NormalTok(")],");],
[#NormalTok("    ");#StringTok("\"Diagnosis\"");#NormalTok(": [");#StringTok("\"Parkinson's\"");#NormalTok("] ");#OperatorTok("*");#NormalTok(" n_pd ");#OperatorTok("+");#NormalTok(" [");#StringTok("\"Healthy\"");#NormalTok("] ");#OperatorTok("*");#NormalTok(" n_healthy,");],
[#NormalTok("    ");#StringTok("\"Total_Reads\"");#NormalTok(": total_reads,");],
[#NormalTok("    ");#StringTok("\"Bifidobacterium\"");#NormalTok(": (np.concatenate([bifido_pd, bifido_healthy]) ");#OperatorTok("*");#NormalTok(" total_reads).astype(");#BuiltInTok("int");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"Lactobacillus\"");#NormalTok(": (np.concatenate([lacto_pd, lacto_healthy]) ");#OperatorTok("*");#NormalTok(" total_reads).astype(");#BuiltInTok("int");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"Bacteroides\"");#NormalTok(": (np.concatenate([bact_pd, bact_healthy]) ");#OperatorTok("*");#NormalTok(" total_reads).astype(");#BuiltInTok("int");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"Prevotella\"");#NormalTok(": (np.concatenate([prev_pd, prev_healthy]) ");#OperatorTok("*");#NormalTok(" total_reads).astype(");#BuiltInTok("int");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"Escherichia\"");#NormalTok(": (np.concatenate([esch_pd, esch_healthy]) ");#OperatorTok("*");#NormalTok(" total_reads).astype(");#BuiltInTok("int");#NormalTok("),");],
[#NormalTok("    ");#StringTok("\"Klebsiella\"");#NormalTok(": (np.concatenate([kleb_pd, kleb_healthy]) ");#OperatorTok("*");#NormalTok(" total_reads).astype(");#BuiltInTok("int");#NormalTok(")");],
[#NormalTok("})");],
[],
[#NormalTok("show(df_raw, classes");#OperatorTok("=");#StringTok("\"display\"");#NormalTok(", lengthMenu");#OperatorTok("=");#NormalTok("[");#DecValTok("5");#NormalTok(", ");#DecValTok("10");#NormalTok("], scrollX");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],));
#Skylighting(([#NormalTok("<IPython.core.display.HTML object>");],));
#block[
#Skylighting(([#NormalTok("<IPython.core.display.HTML object>");],));
] <generate-raw-data-2>
#block[
] <generate-raw-data-3>
If we give these raw numbers to our computer, it will get confused. Because the Parkinson's samples happened to have larger #NormalTok("Total_Reads"); (total sequencing depth), their raw bacteria counts look really high across the board!

Let's look at a #strong[boxplot] of this raw data. A boxplot shows the spread of the data---the box is where most patients fall, and the lines show the extremes.

#Skylighting(([#CommentTok("# Reshape the data for seaborn plotting");],
[#NormalTok("cols ");#OperatorTok("=");#NormalTok(" [");#StringTok("\"Bifidobacterium\"");#NormalTok(", ");#StringTok("\"Lactobacillus\"");#NormalTok(", ");#StringTok("\"Bacteroides\"");#NormalTok(", ");#StringTok("\"Prevotella\"");#NormalTok(", ");#StringTok("\"Escherichia\"");#NormalTok(", ");#StringTok("\"Klebsiella\"");#NormalTok("]");],
[#NormalTok("df_raw_melted ");#OperatorTok("=");#NormalTok(" df_raw.melt(id_vars");#OperatorTok("=");#NormalTok("[");#StringTok("\"Diagnosis\"");#NormalTok("], value_vars");#OperatorTok("=");#NormalTok("cols, var_name");#OperatorTok("=");#StringTok("\"Bacteria\"");#NormalTok(", value_name");#OperatorTok("=");#StringTok("\"Raw_Count\"");#NormalTok(")");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("12");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[#NormalTok("sns.boxplot(data");#OperatorTok("=");#NormalTok("df_raw_melted, x");#OperatorTok("=");#StringTok("\"Bacteria\"");#NormalTok(", y");#OperatorTok("=");#StringTok("\"Raw_Count\"");#NormalTok(", hue");#OperatorTok("=");#StringTok("\"Diagnosis\"");#NormalTok(", palette");#OperatorTok("=");#NormalTok("[");#StringTok("\"#e74c3c\"");#NormalTok(", ");#StringTok("\"#2ecc71\"");#NormalTok("])");],
[#NormalTok("plt.title(");#StringTok("\"Step 1: Raw Counts (Misleading! Parkinson's looks higher in everything)\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Raw Bacteria Count\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("instructions_files/figure-typst/plot-raw-boxplot-output-1.svg"))

== Step 2: Converting to Proportions
<step-2-converting-to-proportions>
To make it a fair comparison, we must mathematically correct the data. We convert the raw counts into #strong[proportions] (percentages) by dividing each bacteria count by the #NormalTok("Total_Reads"); for that specific patient.

#Skylighting(([#CommentTok("# Calculate Proportions");],
[#NormalTok("df_prop ");#OperatorTok("=");#NormalTok(" df_raw.copy()");],
[#ControlFlowTok("for");#NormalTok(" col ");#KeywordTok("in");#NormalTok(" cols:");],
[#NormalTok("    df_prop[col] ");#OperatorTok("=");#NormalTok(" df_prop[col] ");#OperatorTok("/");#NormalTok(" df_prop[");#StringTok("\"Total_Reads\"");#NormalTok("]");],
[],
[#CommentTok("# Show the cleaned proportion data");],
[#NormalTok("df_view ");#OperatorTok("=");#NormalTok(" df_prop[[");#StringTok("\"Patient_ID\"");#NormalTok(", ");#StringTok("\"Diagnosis\"");#NormalTok("] ");#OperatorTok("+");#NormalTok(" cols].");#BuiltInTok("round");#NormalTok("(");#DecValTok("3");#NormalTok(")");],
[#NormalTok("show(df_view, classes");#OperatorTok("=");#StringTok("\"display\"");#NormalTok(", lengthMenu");#OperatorTok("=");#NormalTok("[");#DecValTok("5");#NormalTok(", ");#DecValTok("10");#NormalTok("], scrollX");#OperatorTok("=");#VariableTok("True");#NormalTok(")");],));
Now the data is mathematically sound. But if a human doctor looks at this spreadsheet, can they spot the difference between the sick and healthy patients? Let's check the boxplot of our new proportions.

#Skylighting(([#CommentTok("# Reshape and plot the proportion data");],
[#NormalTok("df_prop_melted ");#OperatorTok("=");#NormalTok(" df_prop.melt(id_vars");#OperatorTok("=");#NormalTok("[");#StringTok("\"Diagnosis\"");#NormalTok("], value_vars");#OperatorTok("=");#NormalTok("cols, var_name");#OperatorTok("=");#StringTok("\"Bacteria\"");#NormalTok(", value_name");#OperatorTok("=");#StringTok("\"Proportion\"");#NormalTok(")");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("12");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[#NormalTok("sns.boxplot(data");#OperatorTok("=");#NormalTok("df_prop_melted, x");#OperatorTok("=");#StringTok("\"Bacteria\"");#NormalTok(", y");#OperatorTok("=");#StringTok("\"Proportion\"");#NormalTok(", hue");#OperatorTok("=");#StringTok("\"Diagnosis\"");#NormalTok(", palette");#OperatorTok("=");#NormalTok("[");#StringTok("\"#e74c3c\"");#NormalTok(", ");#StringTok("\"#2ecc71\"");#NormalTok("])");],
[#NormalTok("plt.title(");#StringTok("\"Step 2: Individual Proportions (Overlapping and Confusing)\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Proportion of Microbiome\"");#NormalTok(")");],
[#NormalTok("plt.show()");],));
#box(image("instructions_files/figure-typst/plot-prop-boxplot-output-1.svg"))

Look at the boxes for #emph[Bifidobacterium] and #emph[Lactobacillus]. The red and green boxes completely overlap! A doctor looking at a patient with 10% #emph[Bifidobacterium] wouldn't know which group they belong to, because healthy and sick people can both have 10%.

== Step 3: Revealing the Hidden Pattern
<step-3-revealing-the-hidden-pattern>
Biological data is messy. Bacteria in the gut interact with each other---they compete for food and space. Sometimes, looking at one bacteria alone tells you nothing.

What happens if we combine these bacterial families into pairs? Let's add them together to create 3 new combined columns.

#Skylighting(([#CommentTok("# Create 3 Combined Columns");],
[#NormalTok("df_prop[");#StringTok("\"Pair1_Bifido_Lacto\"");#NormalTok("] ");#OperatorTok("=");#NormalTok(" df_prop[");#StringTok("\"Bifidobacterium\"");#NormalTok("] ");#OperatorTok("+");#NormalTok(" df_prop[");#StringTok("\"Lactobacillus\"");#NormalTok("]");],
[#NormalTok("df_prop[");#StringTok("\"Pair2_Bact_Prev\"");#NormalTok("] ");#OperatorTok("=");#NormalTok(" df_prop[");#StringTok("\"Bacteroides\"");#NormalTok("] ");#OperatorTok("+");#NormalTok(" df_prop[");#StringTok("\"Prevotella\"");#NormalTok("]");],
[#NormalTok("df_prop[");#StringTok("\"Pair3_Esch_Kleb\"");#NormalTok("] ");#OperatorTok("=");#NormalTok(" df_prop[");#StringTok("\"Escherichia\"");#NormalTok("] ");#OperatorTok("+");#NormalTok(" df_prop[");#StringTok("\"Klebsiella\"");#NormalTok("]");],
[],
[#NormalTok("comb_cols ");#OperatorTok("=");#NormalTok(" [");#StringTok("\"Pair1_Bifido_Lacto\"");#NormalTok(", ");#StringTok("\"Pair2_Bact_Prev\"");#NormalTok(", ");#StringTok("\"Pair3_Esch_Kleb\"");#NormalTok("]");],
[#NormalTok("df_comb_melted ");#OperatorTok("=");#NormalTok(" df_prop.melt(id_vars");#OperatorTok("=");#NormalTok("[");#StringTok("\"Diagnosis\"");#NormalTok("], value_vars");#OperatorTok("=");#NormalTok("comb_cols, var_name");#OperatorTok("=");#StringTok("\"Combined_Pair\"");#NormalTok(", value_name");#OperatorTok("=");#StringTok("\"Proportion\"");#NormalTok(")");],
[],
[#NormalTok("plt.figure(figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("10");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[#NormalTok("sns.boxplot(data");#OperatorTok("=");#NormalTok("df_comb_melted, x");#OperatorTok("=");#StringTok("\"Combined_Pair\"");#NormalTok(", y");#OperatorTok("=");#StringTok("\"Proportion\"");#NormalTok(", hue");#OperatorTok("=");#StringTok("\"Diagnosis\"");#NormalTok(", palette");#OperatorTok("=");#NormalTok("[");#StringTok("\"#e74c3c\"");#NormalTok(", ");#StringTok("\"#2ecc71\"");#NormalTok("])");],
[#NormalTok("plt.title(");#StringTok("\"Step 3: Combined Proportions (The Hidden Pattern is Revealed!)\"");#NormalTok(")");],
[#NormalTok("plt.ylabel(");#StringTok("\"Combined Proportion\"");#NormalTok(")");],
[#CommentTok("# Make x-axis labels cleaner");],
[#NormalTok("plt.xticks(ticks");#OperatorTok("=");#NormalTok("[");#DecValTok("0");#NormalTok(", ");#DecValTok("1");#NormalTok(", ");#DecValTok("2");#NormalTok("], labels");#OperatorTok("=");#NormalTok("[");#StringTok("\"Pair 1");#CharTok("\\n");#StringTok("(Bifido+Lacto)\"");#NormalTok(", ");#StringTok("\"Pair 2");#CharTok("\\n");#StringTok("(Bact+Prev)\"");#NormalTok(", ");#StringTok("\"Pair 3");#CharTok("\\n");#StringTok("(Esch+Kleb)\"");#NormalTok("])");],
[#NormalTok("plt.show()");],));
#box(image("instructions_files/figure-typst/plot-combined-boxplot-output-1.svg"))

= The Tech: What is a Predictive Model?
<the-tech-what-is-a-predictive-model>
If we give you a spreadsheet with hundreds of rows of patients and thousands of columns of bacteria, your human brain cannot easily spot the pattern. It's too much information.

This is where #strong[Machine Learning] comes in. Instead of a human trying to figure out the rules, we let a computer figure it out through trial and error.

== Using a Predictive Model to Describe the Separation
<using-a-predictive-model-to-describe-the-separation>
Before we jump into complex networks, let's look at a simpler predictive model called #strong[Logistic Regression].

In our previous step, we discovered that #emph[Pair 1] (Bifidobacterium + Lactobacillus) was a great separator. How do we turn that separation into a mathematical prediction? We map the diagnosis to numbers: #strong[Healthy = 0] and #strong[Parkinson's = 1]. Then, we ask the computer to draw a smooth curve (an "S-curve") that connects the two.

Let's use Python to fit a Logistic Regression model to our 3 pairs and plot the results.

#Skylighting(([#ImportTok("import");#NormalTok(" matplotlib.pyplot ");#ImportTok("as");#NormalTok(" plt");],
[#ImportTok("import");#NormalTok(" numpy ");#ImportTok("as");#NormalTok(" np");],
[#ImportTok("from");#NormalTok(" sklearn.linear_model ");#ImportTok("import");#NormalTok(" LogisticRegression");],
[],
[#CommentTok("# Convert Diagnosis to numbers: Healthy = 0, Parkinson's = 1");],
[#NormalTok("y ");#OperatorTok("=");#NormalTok(" (df_prop[");#StringTok("\"Diagnosis\"");#NormalTok("] ");#OperatorTok("==");#NormalTok(" ");#StringTok("\"Parkinson's\"");#NormalTok(").astype(");#BuiltInTok("int");#NormalTok(")");],
[],
[#NormalTok("fig, (ax1, ax2, ax3) ");#OperatorTok("=");#NormalTok(" plt.subplots(");#DecValTok("1");#NormalTok(", ");#DecValTok("3");#NormalTok(", figsize");#OperatorTok("=");#NormalTok("(");#DecValTok("15");#NormalTok(", ");#DecValTok("5");#NormalTok("))");],
[#NormalTok("axes ");#OperatorTok("=");#NormalTok(" [ax1, ax2, ax3]");],
[#NormalTok("pairs ");#OperatorTok("=");#NormalTok(" [");#StringTok("\"Pair1_Bifido_Lacto\"");#NormalTok(", ");#StringTok("\"Pair2_Bact_Prev\"");#NormalTok(", ");#StringTok("\"Pair3_Esch_Kleb\"");#NormalTok("]");],
[#NormalTok("titles ");#OperatorTok("=");#NormalTok(" [");#StringTok("\"Pair 1 (The True Pattern)\"");#NormalTok(", ");#StringTok("\"Pair 2 (Distraction)\"");#NormalTok(", ");#StringTok("\"Pair 3 (Noise)\"");#NormalTok("]");],
[],
[#ControlFlowTok("for");#NormalTok(" ax, pair, title ");#KeywordTok("in");#NormalTok(" ");#BuiltInTok("zip");#NormalTok("(axes, pairs, titles):");],
[#NormalTok("    X ");#OperatorTok("=");#NormalTok(" df_prop[[pair]].values");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# Fit the Logistic Regression model");],
[#NormalTok("    model ");#OperatorTok("=");#NormalTok(" LogisticRegression()");],
[#NormalTok("    model.fit(X, y)");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# Create smooth line for the S-curve");],
[#NormalTok("    X_test ");#OperatorTok("=");#NormalTok(" np.linspace(X.");#BuiltInTok("min");#NormalTok("(), X.");#BuiltInTok("max");#NormalTok("(), ");#DecValTok("300");#NormalTok(").reshape(");#OperatorTok("-");#DecValTok("1");#NormalTok(", ");#DecValTok("1");#NormalTok(")");],
[#NormalTok("    y_prob ");#OperatorTok("=");#NormalTok(" model.predict_proba(X_test)[:, ");#DecValTok("1");#NormalTok("] ");#CommentTok("# Probability of being PD (Class 1)");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# Scatter plot of actual patients");],
[#NormalTok("    ax.scatter(X[y");#OperatorTok("==");#DecValTok("0");#NormalTok("], y[y");#OperatorTok("==");#DecValTok("0");#NormalTok("], color");#OperatorTok("=");#StringTok("'#2ecc71'");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Actual Healthy (0)\"");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok("    ax.scatter(X[y");#OperatorTok("==");#DecValTok("1");#NormalTok("], y[y");#OperatorTok("==");#DecValTok("1");#NormalTok("], color");#OperatorTok("=");#StringTok("'#e74c3c'");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Actual PD (1)\"");#NormalTok(", alpha");#OperatorTok("=");#FloatTok("0.5");#NormalTok(")");],
[#NormalTok("    ");],
[#NormalTok("    ");#CommentTok("# Plot the regression curve");],
[#NormalTok("    ax.plot(X_test, y_prob, color");#OperatorTok("=");#StringTok("'black'");#NormalTok(", linewidth");#OperatorTok("=");#DecValTok("3");#NormalTok(", label");#OperatorTok("=");#StringTok("\"Logistic Prediction Curve\"");#NormalTok(")");],
[#NormalTok("    ");],
[#NormalTok("    ax.set_title(title)");],
[#NormalTok("    ax.set_xlabel(");#StringTok("\"Combined Proportion\"");#NormalTok(")");],
[#NormalTok("    ax.set_ylabel(");#StringTok("\"Probability of Parkinson's\"");#NormalTok(")");],
[#NormalTok("    ax.set_yticks([");#DecValTok("0");#NormalTok(", ");#FloatTok("0.5");#NormalTok(", ");#FloatTok("1.0");#NormalTok("])");],
[#NormalTok("    ax.set_yticklabels([");#StringTok("'0 (Healthy)'");#NormalTok(", ");#StringTok("'0.5'");#NormalTok(", ");#StringTok("'1 (PD)'");#NormalTok("])");],
[#NormalTok("    ax.legend()");],
[],
[#NormalTok("plt.tight_layout()");],
[#NormalTok("plt.show()");],));
#box(image("instructions_files/figure-typst/plot-logistic-regression-output-1.svg"))

#strong[Understanding the Model:] Look at the black line in the first chart. It tells us exactly how to predict the disease. If a new patient walks in with a Pair 1 proportion of 0.15, the black line is at #NormalTok("1");, predicting they have Parkinson's. If they have a proportion of 0.35, the curve drops down to #NormalTok("0");, predicting they are Healthy.

For Pairs 2 and 3, the black line is flat. The model is saying, #emph["This data is useless, it doesn't help me predict anything."]

== Why We Need Neural Networks
<why-we-need-neural-networks>
Logistic Regression is great, but notice that #strong[we] had to manually combine #emph[Bifidobacterium] and #emph[Lactobacillus] to create Pair 1. We had to do the hard work of finding the pattern.

In reality, the gut has thousands of bacteria ($x_1 \, x_2 \, x_3 dots.h$). We don't know which ones to add together. We want to find some hidden, combined features (let's call them $z_1 \, z_2 dots.h$) that are highly predictive of the final diagnosis ($y$).

Instead of humans guessing the formulas, we build a #strong[Neural Network]. We let machine learning find the mathematical functions $z_j = f_j \( x \)$ entirely on its own.

Think of a Neural Network like a detective agency with several floors (called #strong[Layers]):

+ #strong[The First Layer (Input, $x$):] Looks at the raw spreadsheet numbers for a patient (thousands of individual bacteria).
+ #strong[The Middle Layers (Hidden Layers, $z$):] Looks for hidden patterns. It automatically tests millions of combinations to create new features ($z_j$). It might figure out mathematically: #emph["Hey, whenever Bacteria A is high and Bacteria B is low, that's a strong signal!"]
+ #strong[The Final Layer (Output, $y$):] Takes those hidden signals and draws a final logistic curve to make a guess: #emph["Based on these patterns, the probability is 85% that this person has Parkinson's."]

Here is a visual map of what that network looks like:

#block[

#block[
#box(image("instructions_files/figure-typst/mermaid-figure-1.png", height: 5.02in, width: 9.77in))

]

]
#strong[How does it learn to find $z$?] We show the network hundreds of examples where we #emph[already know] the answer. It makes a guess. If it guesses wrong, it automatically tweaks its own internal math so it can guess better the next time. We call this #strong[training] the model.

#horizontalrule

= Collection of Microbiome Data Related To Parkinson
<collection-of-microbiome-data-related-to-parkinson>
Because formatting raw DNA sequences is complex, we have already done the messy spreadsheet cleanup for you.

- #strong[Core Dataset:] A preprocessed dataset is available in the #NormalTok("datasets"); directory of this GitHub repository: #link("https://github.com/longhaiSK/PDNN")[PDNN GitHub Repo].

- #strong[Data Collection Task (Student A):] One team member should take the lead on gathering additional data to test. Follow the exact steps outlined in this #link("https://colab.research.google.com/drive/170dd6Qv-IgYyj4_WxvSOlmS8N5wtNGgo#scrollTo=3V9zVKkpWlQe")[Google Colab Data Notebook]. Additional instructions are located in the repository's "More Datasets" directory.

#horizontalrule

= The Lab Bench: Computing in Google Colab
<the-lab-bench-computing-in-google-colab>
You will build your Neural Network using a tool called #strong[TensorFlow] inside #strong[Google Colab]. Colab is a free, cloud-based workspace that runs right in your web browser.

== Setting Up Colab
<setting-up-colab>
+ Go to #link("https://colab.research.google.com/")[Google Colab] and create a new notebook.
+ Make your code run faster by turning on the GPU: Go to #NormalTok("Runtime"); \> #NormalTok("Change runtime type"); \> select #NormalTok("GPU"); under Hardware accelerator.

#block[
#callout(
body: 
[
If you have never coded a Neural Network before, don't panic. Run through these beginner tutorials directly in Colab before starting your main project. They walk you through the exact code you will need:

- #link("https://colab.research.google.com/github/tensorflow/docs/blob/master/site/en/tutorials/quickstart/beginner.ipynb")[TensorFlow 2 Quickstart for Beginners]
- #link("https://colab.research.google.com/github/tensorflow/docs/blob/master/site/en/tutorials/keras/classification.ipynb")[Basic Classification with Keras]

]
, 
title: 
[
Helpful Tutorials for Beginners
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]

#horizontalrule

= The Writing Desk: Creating Your Report in Posit Cloud
<the-writing-desk-creating-your-report-in-posit-cloud>
Google Colab is fantastic for running heavy math calculations, but it is terrible for writing clean, professional reports. For that, we split our workflow: #strong[Compute in Colab, Write in Posit Cloud.]

Posit Cloud supports #strong[Quarto]---a system that lets you write using a "Visual Editor" (just like Google Docs or Microsoft Word) while it handles making it look like a professional science paper in the background.

== Step-by-Step Writing Setup
<step-by-step-writing-setup>
+ Go to #link("https://posit.cloud/")[Posit Cloud] and sign up for a free account.

+ Click #strong[New Project] \> #strong[New RStudio Project].

+ Go to #strong[File] \> #strong[New File] \> #strong[Quarto Document…] Give it a title and add your names.

+ #strong[Crucial Step:] Look at the top left corner of your document and click the #strong[Visual] button. This switches you from code-view to a clean word processor!

+ Transfer your graphs: Save your accuracy charts in Colab as image files (e.g., #NormalTok(".png");), download them, and upload them to the #strong[Files] pane in Posit Cloud. Insert them into your text using the Image icon.

+ Click the #strong[Render] button (the blue arrow at the top) to generate your final web page or PDF.

#block[
#callout(
body: 
[
Whenever you add a chart or result to your report, explain it using these three steps so your reader understands #emph[why] you included it:

+ #strong[What:] What are we looking at? #emph[\(e.g., "This graph shows our model's accuracy as it practiced over 50 rounds.")]

+ #strong[So What:] Why does this matter? #emph[\(e.g., "The accuracy stops improving around round 30, meaning the model stopped learning anything new.")]

+ #strong[Now What:] What did you do next? #emph[\(e.g., "Because it stopped learning, we changed the layers in our network to see if it would help…")]

]
, 
title: 
[
Writing Tip: The "What, So What, Now What" Framework
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]

#horizontalrule

= Appendix: Starter Template for Your Report
<appendix-starter-template-for-your-report>
Copy the text inside the box below, switch Posit Cloud to #strong[Source] mode, paste it in, and then switch back to #strong[Visual] mode to start writing!

#Skylighting(([#CommentTok("---");],
[#AnnotationTok("title:");#CommentTok(" \"Predicting Parkinson's Disease from Gut Microbiome Data\"");],
[#AnnotationTok("author:");#CommentTok(" \"Your Names Here\"");],
[#AnnotationTok("format:");#CommentTok(" html");],
[#CommentTok("---");],
[],
[#FunctionTok("## Introduction");],
[#CommentTok("<!-- Write 2-3 sentences explaining what Parkinson's Disease is and why the bacteria in our gut might act as a clue to diagnosing it. -->");],
[],
[#FunctionTok("## The Dataset");],
[#CommentTok("<!-- Explain where the data came from. Insert a small table here showing how many patients vs. healthy controls are in our spreadsheet. -->");],
[],
[#FunctionTok("## Our Neural Network Model");],
[#CommentTok("<!-- Insert an image of your model architecture or summary here. Explain how many layers you chose for your \"detective agency\" and why. -->");],
[],
[#FunctionTok("## Results");],
[#CommentTok("<!-- Insert your accuracy charts here. Remember to use the What, So What, Now What framework to explain them! -->");],
[],
[#FunctionTok("## Conclusion");],
[#CommentTok("<!-- Did the model successfully predict PD? What was the hardest part of building it, and what would you try next time? -->");],));



