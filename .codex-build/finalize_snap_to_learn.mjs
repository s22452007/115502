import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { PresentationFile } from "@oai/artifact-tool";

const workspaceDir = "C:/Users/billp/Desktop/my_project/115502";
const skillDir = "C:/Users/billp/.codex/plugins/cache/openai-primary-runtime/presentations/26.1123.11515/skills/presentations";
const candidatePath = path.join(workspaceDir, "output", "Snap_to_Learn_系統介紹.pptx");
const finalPath = path.join(workspaceDir, "output", "Snap_to_Learn_系統介紹_final.pptx");
const stagingDir = path.join(workspaceDir, ".codex-finalizer");
const pythonExecutable = "C:/Users/billp/AppData/Local/Programs/Python/Python310/python.exe";
await fs.mkdir(stagingDir, { recursive: true });
await fs.mkdir(path.dirname(finalPath), { recursive: true });
const presentation = await PresentationFile.importPptx(await (await import("@oai/artifact-tool")).FileBlob.load(candidatePath));
const { finalizePresentation } = await import(pathToFileURL(path.join(skillDir, "container_tools/artifact_tool_utils.mjs")).href);
const result = await finalizePresentation({
  workspaceDir,
  candidatePath,
  finalPath,
  pythonExecutable,
  integrityValidatorPath: path.join(skillDir, "container_tools/inspect_presentation_package_integrity.py"),
  layoutValidatorPath: path.join(skillDir, "container_tools/inspect_presentation_layout_geometry.py"),
  layoutArgs: ["--expected-slide-size-emu", "12192000,6858000", "--validate-heading-fit"],
  explicitTotalSlideCount: 10,
  requiredNativeTableOwnerSlides: [],
  requiredNativeChartOwnerSlides: [],
  fontPolicy: { basis: "design", families: ["Arial"] },
  verifyArtifactToolImport: true,
  receiptPath: path.join(stagingDir, "Snap_to_Learn_系統介紹_final.pptx.validation.json"),
});
console.log(JSON.stringify(result));
