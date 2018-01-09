def _generate_script_impl(ctx):
  script_file = ctx.actions.declare_file(ctx.label.name + ".bash")
  ctx.actions.write(output=script_file, is_executable=True, content="""
OUTPUT="$({0} 2>&1)"
if [ $? -eq 0 ]; then
  echo success
  echo "Expected failure, got success"
  exit 1
fi
if [[ $OUTPUT != *"WARNING: DATA RACE"* ]]; then
  echo "Expected WARNING: DATA RACE and it was not present"
  echo
  echo $(OUTPUT)
  exit 1
fi
exit 0
""".format(ctx.file.binary.short_path))
  return struct(
      files = depset([script_file]),
  )

generate_script = rule(
    _generate_script_impl,
    attrs = {
        "binary": attr.label(
            allow_files = True,
            single_file = True,
        ),
    },
)
