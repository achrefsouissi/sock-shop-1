filegroup(
    name = "package-srcs",
    srcs = glob(["**"]),
    tags = ["automanaged"],
    visibility = ["//visibility:private"],
)

filegroup(
    name = "all-srcs",
    srcs = [
        ":package-srcs",
        "//pkg/apis/networktopology:all-srcs",
        "//pkg/generated/clientset/versioned:all-srcs",
        "//pkg/generated/informers/externalversions:all-srcs",
        "//pkg/generated/listers/networktopology/v1alpha1:all-srcs",
    ],
    tags = ["automanaged"],
    visibility = ["//visibility:public"],
)
