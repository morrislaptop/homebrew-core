class Deno < Formula
  desc "Command-line JavaScript / TypeScript engine"
  homepage "https://deno.land/"
  url "https://github.com/denoland/deno/releases/download/v0.25.0/deno_src.tar.gz"
  version "0.25.0"
  sha256 "4d698753384b46240c28fa4874a595990e06ee89ae1af28b632fb1dffbf091e7"

  bottle do
    cellar :any_skip_relocation
    sha256 "0616e9a4d596e0c35cdbf61680521b36e30fcf761068caa6b6fc377670ac7ed8" => :catalina
    sha256 "bf35c500110fb1d8f54ab2d454375b0f382a9282a8e67c9be60bf2e7eacec824" => :mojave
    sha256 "99f4a047ebdc817c9d228087da449a2fcd6e60517ee458d35950b8c45435f3e8" => :high_sierra
  end

  depends_on "llvm" => :build if DevelopmentTools.clang_build_version < 1100
  depends_on "ninja" => :build
  depends_on "rust" => :build

  depends_on :xcode => ["10.0", :build] # required by v8 7.9+

  resource "gn" do
    url "https://gn.googlesource.com/gn.git",
      :revision => "152c5144ceed9592c20f0c8fd55769646077569b"
  end

  def install
    # Build gn from source (used as a build tool here)
    (buildpath/"gn").install resource("gn")
    cd "gn" do
      system "python", "build/gen.py"
      system "ninja", "-C", "out/", "gn"
    end

    # env args for building a release build with our clang, ninja and gn
    ENV["DENO_NO_BINARY_DOWNLOAD"] = "1"
    ENV["DENO_GN_PATH"] = buildpath/"gn/out/gn"
    args = %W[
      clang_use_chrome_plugins=false
      mac_deployment_target="#{MacOS.version}"
      treat_warnings_as_errors=false
    ]
    if DevelopmentTools.clang_build_version < 1100
      # build with llvm and link against system libc++ (no runtime dep)
      args << "clang_base_path=\"#{Formula["llvm"].prefix}\""
      ENV.remove "HOMEBREW_LIBRARY_PATHS", Formula["llvm"].opt_lib
    else # build with system clang
      args << "clang_base_path=\"/usr/\""
    end
    ENV["DENO_BUILD_ARGS"] = args.join(" ")

    cd "cli" do
      system "cargo", "install", "-vv", "--locked", "--root", prefix, "--path", "."
    end

    # Install bash and zsh completion
    output = Utils.popen_read("#{bin}/deno completions bash")
    (bash_completion/"deno").write output
    output = Utils.popen_read("#{bin}/deno completions zsh")
    (zsh_completion/"_deno").write output
  end

  test do
    (testpath/"hello.ts").write <<~EOS
      console.log("hello", "deno");
    EOS
    hello = shell_output("#{bin}/deno run hello.ts")
    assert_includes hello, "hello deno"
  end
end
