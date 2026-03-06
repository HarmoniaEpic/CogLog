package io.github.harmoniaepic.coglog;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * CogLog CLI v0.9.1
 *
 * <p>Usage:
 *   java -jar coglog-0.9.1.jar read
 *   echo '...' | java -jar coglog-0.9.1.jar write
 *   java -jar coglog-0.9.1.jar clear</p>
 */
public class Main {

    private static void printUsage() {
        System.out.print("""
            usage: coglog-cli <read|write|clear>

              read    — display the previous turn's coglog
              write   — save current turn (reads JSON from stdin)
              clear   — reset coglog

            write expects JSON on stdin (all fields required):
              {
                "user": "user's message",
                "thinking": "AI thinking process",
                "assistant": "AI output",
                "current_focus": "what is happening right now",
                "theory_of_mind": "user intent/state inference",
                "self_narrative": "improvised self-story at this moment",
                "annotation": "note to future self"
              }

              fact layer (user, thinking, assistant): non-empty string required
              interpretation layer (current_focus, theory_of_mind,
                self_narrative, annotation): string required, empty string acceptable
            """);
    }

    public static void main(String[] args) {
        try {
            // Parse --coglog-dir <path> (priority: arg > COGLOG_DIR env > default)
            int argOffset = 0;
            CogLog cl;
            if (args.length >= 2 && args[0].equals("--coglog-dir")) {
                cl = new CogLog(java.nio.file.Path.of(args[1]));
                argOffset = 2;
            } else {
                cl = new CogLog();
            }
            String[] cmdArgs = java.util.Arrays.copyOfRange(args, argOffset, args.length);

            if (cmdArgs.length < 1) {
                printUsage();
                return;
            }

            switch (cmdArgs[0]) {
                case "read" -> {
                    Map<String, Object> entry = cl.read();
                    if (entry == null) {
                        System.out.println("(no coglog found)");
                    } else {
                        System.out.println(CogLog.toJson(entry, 0));
                    }
                }
                case "write" -> {
                    String input = new String(System.in.readAllBytes(), StandardCharsets.UTF_8);
                    Map<String, Object> data = CogLog.parseJson(input);
                    Map<String, String> writeArgs = new LinkedHashMap<>();
                    for (String key : new String[]{"user", "thinking", "assistant",
                            "current_focus", "theory_of_mind", "self_narrative", "annotation"}) {
                        Object val = data.get(key);
                        writeArgs.put(key, val != null ? val.toString() : null);
                    }
                    Map<String, Object> entry = cl.write(writeArgs);
                    System.out.printf("coglog: turn %d written%n", ((Number) entry.get("turn_id")).intValue());
                }
                case "clear" -> {
                    Map<String, Object> result = cl.clear();
                    if (Boolean.TRUE.equals(result.get("cleared"))) {
                        System.out.println("coglog: cleared");
                    } else {
                        System.out.printf("coglog: %s%n", result.get("reason"));
                    }
                }
                default -> {
                    printUsage();
                    System.exit(1);
                }
            }
        } catch (IllegalArgumentException e) {
            System.err.printf("coglog error: %s%n", e.getMessage());
            System.exit(1);
        } catch (Exception e) {
            System.err.printf("coglog error: %s%n", e.getMessage());
            System.exit(1);
        }
    }
}
