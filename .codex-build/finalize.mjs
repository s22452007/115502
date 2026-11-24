import path from 'node:path';
import fs from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { finalizePresentation } = await import(pathToFileURL('C:/Users/billp/.codex/plugins/cache/openai-primary-runtime/presentations/26.1026.10807/skills/presentations/container_tools/artifact_tool_utils.mjs').href);
process.env.RUNTIME_NODE_MODULES = 'C:/Users/billp/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules';

const workspaceDir = 'C:/Users/billp/Desktop/my_project/115502';
const skillDir = 'C:/Users/billp/.codex/plugins/cache/openai-primary-runtime/presentations/26.1026.10807/skills/presentations';
const candidatePath = path.join(workspaceDir, '.codex-build', 'candidate.pptx');
const finalPath = path.join(workspaceDir, 'output', 'Snap_to_Learn_人無我有_簡報.pptx');
await fs.mkdir(path.dirname(finalPath), { recursive: true });
const result = await finalizePresentation({
  explicitTotalSlideCount: 9,
  requiredNativeTableOwnerSlides: [],
  requiredNativeChartOwnerSlides: [],
  workspaceDir,
  candidatePath,
  finalPath,
  pythonExecutable: 'C:/Users/billp/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',
  integrityValidatorPath: path.join(skillDir, 'container_tools/inspect_presentation_package_integrity.py'),
  layoutValidatorPath: path.join(skillDir, 'container_tools/inspect_presentation_layout_geometry.py'),
  layoutArgs: ['--expected-slide-size-emu', '12192000,6858000', '--validate-bullet-geometry', '--validate-heading-fit'],
  fontPolicy: { basis: 'design', families: ['Aptos'] },
  verifyArtifactToolImport: true,
  receiptPath: path.join(workspaceDir, '.codex-build', 'Snap_to_Learn.validation.json'),
});
console.log(JSON.stringify(result, null, 2));
