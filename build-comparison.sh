OUT=$(mktemp -d)
for arch in x86 x86-64; do
    for host in cl ccl32 ccl64 clisp; do
        mkdir -p $OUT/$arch/$host
    done
done

for arch in x86 x86-64; do
    for host in cl ccl32 ccl64 clisp; do
        case $host in
            cl) xc_host=cl;;
            ccl32) xc_host='lx86cl -b';;
            ccl64) xc_host='lx86cl64 -b';;
            clisp) xc_host='clisp -ansi -on-error abort';;
        esac
        ./make.sh --arch=$arch --xc-host="$xc_host" "$@" && tar cf - run-cl.sh src/runtime/cl obj/from-xc output | tar -C $OUT/$arch/$host -xf -
    done
done

echo done: cd $OUT
