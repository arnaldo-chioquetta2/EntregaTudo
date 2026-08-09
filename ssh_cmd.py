import argparse
import shlex
import sys


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--user", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--command")
    parser.add_argument("--command-file")
    parser.add_argument("--upload-local")
    parser.add_argument("--upload-remote")
    args = parser.parse_args()

    wants_command = bool(args.command or args.command_file)
    wants_upload = bool(args.upload_local or args.upload_remote)

    if not wants_command and not wants_upload:
        parser.error("one of --command/--command-file or --upload-local/--upload-remote is required")

    if bool(args.upload_local) != bool(args.upload_remote):
        parser.error("--upload-local and --upload-remote must be provided together")

    if args.command_file:
        with open(args.command_file, "r", encoding="utf-8") as handle:
            command = handle.read()
    else:
        command = args.command

    try:
        import paramiko
    except Exception as exc:
        print(f"PARAMIKO_IMPORT_ERROR: {exc}", file=sys.stderr)
        return 2

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    try:
        client.connect(
            hostname=args.host,
            username=args.user,
            password=args.password,
            look_for_keys=False,
            allow_agent=False,
            timeout=20,
        )
        if wants_upload:
            try:
                sftp = client.open_sftp()
                try:
                    sftp.put(args.upload_local, args.upload_remote)
                finally:
                    sftp.close()
            except Exception:
                with open(args.upload_local, "rb") as handle:
                    data = handle.read()
                remote_tmp = f"{args.upload_remote}.codex_tmp"
                upload_cmd = (
                    f"cat > {shlex.quote(remote_tmp)} && "
                    f"mv {shlex.quote(remote_tmp)} {shlex.quote(args.upload_remote)}"
                )
                stdin, stdout, stderr = client.exec_command(upload_cmd, timeout=60)
                stdin.channel.sendall(data)
                stdin.channel.shutdown_write()
                out = stdout.read().decode("utf-8", errors="replace")
                err = stderr.read().decode("utf-8", errors="replace")
                exit_status = stdout.channel.recv_exit_status()
                if out:
                    print(out, end="")
                if err:
                    print(err, file=sys.stderr, end="")
                if exit_status != 0:
                    return exit_status
            print(f"UPLOADED {args.upload_local} -> {args.upload_remote}")

        if wants_command:
            stdin, stdout, stderr = client.exec_command(command, timeout=60)
            out = stdout.read().decode("utf-8", errors="replace")
            err = stderr.read().decode("utf-8", errors="replace")
            exit_status = stdout.channel.recv_exit_status()
            print(out, end="")
            if err:
                print(err, file=sys.stderr, end="")
            return exit_status

        return 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
