{
	nixpkgs ? import <nixpkgs> {},

	lib ? nixpkgs.lib,
	pkgs ? nixpkgs.pkgs,
}:

pkgs.stdenv.mkDerivation {
	name = "journal-forwarder";
	
	meta = {
		description = "Forward journald logs over HTTP somewhat reliabily.";
		homepage = https://github.com/kevincox/journal-forwarder;
	};
	
	src = builtins.filterSource (name: type:
		(lib.hasPrefix (toString ./journal-forwarder.sh) name)
	) ./.;
	
	buildInputs = [ pkgs.makeWrapper ];
	
	installPhase = ''
		install -Dm755 journal-forwarder.sh "$out/bin/journal-forwarder"
		wrapProgram $out/bin/journal-forwarder \
			--set PATH ${lib.makeBinPath (with pkgs; [
				coreutils
				curl
				gnused
				jq
				systemd
				utillinux
			])}
	'';
}
