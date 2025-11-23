//===---*- Greatdori! -*---------------------------------------------------===//
//
// TSCompilerUtils.js
//
// This source file is part of the Greatdori! open source project
//
// Copyright (c) 2025 the Greatdori! project authors
// Licensed under Apache License v2.0
//
// See https://greatdori.com/LICENSE.txt for license information
// See https://greatdori.com/CONTRIBUTORS.txt for the list of Greatdori! project authors
//
//===----------------------------------------------------------------------===//

// Precondition: TypeScriptCompiler.js is loaded into context
// Precondition: const _tsLibrary; // TypeScript library definations

function compileTS(code) {
    const sourceFile = ts.createSourceFile(
        "source.ts", code, ts.ScriptTarget.Latest
    );
    const library = ts.createSourceFile(
        "lib.d.ts", _tsLibrary, ts.ScriptTarget.Latest
    )
    
    let result = "";
    
    const customCompilerHost = {
        getSourceFile: (name, options) => {
            if (name === "source.ts") {
                return sourceFile;
            } else if (name === "lib.d.ts") {
                return library;
            }
        },
        writeFile: (filename, data) => {
            if (filename === "source.js") {
                result = data;
            }
        },
        getDefaultLibFileName: () => "lib.d.ts",
        useCaseSensitiveFileNames: () => false,
        getCanonicalFileName: filename => filename,
        getCurrentDirectory: () => "",
        getNewLine: () => "\n",
        getDirectories: () => [],
        fileExists: () => true,
        readFile: () => ""
    };
    
    const program = ts.createProgram(
        ["source.ts"], {}, customCompilerHost
    );
    let emitResult = program.emit();
    
    let allDiagnostics = ts
        .getPreEmitDiagnostics(program)
        .concat(emitResult.diagnostics);
    
    let diagnostics = [];
    
    allDiagnostics.forEach(diagnostic => {
        let message = ts.flattenDiagnosticMessageText(diagnostic.messageText, "\n");
        if (diagnostic.file) {
            let { line, character } = ts.getLineAndCharacterOfPosition(diagnostic.file, diagnostic.start);
            diagnostics.push({
                line: line + 1,
                column: character + 1,
                message: message
            });
        } else {
            diagnostics.push({
                line: 0,
                column: 0,
                message: message
            });
        }
    });
    
    return {
        diagnostics: diagnostics,
        jsCode: result
    };
}
