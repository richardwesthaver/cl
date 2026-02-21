#!/bin/false
# Not a shell script, but something intended to be sourced from shell scripts

# This ensures that CL_PWD is a path understandable to SBCL.

sbcl_pwd() {
    case "${OSTYPE:-}" in
        cygwin)
            CL_PWD="`cygpath -m \"$(pwd)\"`" ;;
        msys)
            CL_PWD="`pwd -W`" ;;
        *)
            CL_PWD="`pwd`" ;;
    esac
    export CL_PWD
}
