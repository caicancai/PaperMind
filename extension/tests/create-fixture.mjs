import {
  PDFDocument,
  PDFHexString,
  PDFName,
  PDFNull,
  StandardFonts,
  rgb
} from "pdf-lib";

export async function createPdfFixture({ withOutline = true } = {}) {
  const document = await PDFDocument.create();
  const regular = await document.embedFont(StandardFonts.Helvetica);
  const bold = await document.embedFont(StandardFonts.HelveticaBold);
  const sections = [
    ["PaperMind Browser Test Paper", "Abstract", "This paper studies practical browser based paper reading assistants."],
    ["1 Introduction", "Introduction", "Long papers require lazy rendering and reliable chapter navigation."],
    ["2 Method", "Method", "Our objective is y = W x + b and the loss is L = sum_i error_i^2."],
    ["3 Experiments", "Experiments", "We evaluate translation, selection context, and streaming AI responses."],
    ["4 Results", "Results", "The browser workflow reduces context switching during focused reading."],
    ["5 Discussion", "Discussion", "The implementation keeps PDF files local by default."],
    ["6 Conclusion", "Conclusion", "A Chrome extension can provide a complete reading workflow."],
    ["References", "References", "PDF.js documentation and Chrome extension documentation."]
  ];

  const pages = sections.map(([title, heading, body], index) => {
    const page = document.addPage([612, 792]);
    page.drawText(title, { x: 54, y: 720, size: index === 0 ? 24 : 20, font: bold });
    page.drawText(heading, { x: 54, y: 675, size: 16, font: bold, color: rgb(0.12, 0.25, 0.48) });
    page.drawText(body, { x: 54, y: 635, size: 12, font: regular, maxWidth: 500 });
    for (let line = 0; line < 24; line += 1) {
      page.drawText(
        `Page ${index + 1} supporting paragraph ${line + 1}. PaperMind keeps the reading context visible.`,
        { x: 54, y: 600 - line * 21, size: 10, font: regular }
      );
    }
    return page;
  });

  if (withOutline) {
    const context = document.context;
    const outlinesRef = context.nextRef();
    const itemRefs = sections.map(() => context.nextRef());
    sections.forEach(([title], index) => {
      const values = {
        Title: PDFHexString.fromText(title),
        Parent: outlinesRef,
        Dest: context.obj([pages[index].ref, PDFName.of("Fit")])
      };
      if (index > 0) values.Prev = itemRefs[index - 1];
      if (index < itemRefs.length - 1) values.Next = itemRefs[index + 1];
      context.assign(itemRefs[index], context.obj(values));
    });
    context.assign(
      outlinesRef,
      context.obj({
        Type: PDFName.of("Outlines"),
        First: itemRefs[0],
        Last: itemRefs.at(-1),
        Count: sections.length
      })
    );
    document.catalog.set(PDFName.of("Outlines"), outlinesRef);
    document.catalog.set(PDFName.of("PageMode"), PDFName.of("UseOutlines"));
  }

  return Buffer.from(await document.save());
}
