import argv
import clip.{type Command}
import clip/help
import clip/opt.{type Opt}
import gleam/io
import init_db
import reset_password

type Args {
  InitDB(sql_path: String, output_db_path: String)
  PasswordReset(db_path: String)
}

pub fn main() -> Nil {
  let result =
    command()
    |> clip.help(help.simple(
      "kaniwani",
      "CLI tool for managing the KaniWani database.",
    ))
    |> clip.run(argv.load().arguments)

  case result {
    Ok(InitDB(sql_path:, output_db_path:)) ->
      init_db.init_db(sql_path, output_db_path)
    Ok(PasswordReset(db_path:)) -> reset_password.reset_password(db_path)
    Error(error) -> io.println_error(error)
  }
}

fn command() -> Command(Args) {
  clip.subcommands([
    #("init-db", init_db_command()),
    #("reset-password", reset_password_command()),
  ])
}

fn init_db_command() -> Command(Args) {
  clip.command({
    use sql_path <- clip.parameter
    use output_db_path <- clip.parameter
    InitDB(sql_path:, output_db_path:)
  })
  |> clip.opt(sql_path_opt())
  |> clip.opt(output_db_path_opt())
}

fn reset_password_command() -> Command(Args) {
  clip.command({
    use db_path <- clip.parameter
    PasswordReset(db_path:)
  })
  |> clip.opt(db_path_opt())
}

fn sql_path_opt() -> Opt(String) {
  opt.new("sql-path")
  |> opt.help("The path to the directory with the application SQL files")
}

fn output_db_path_opt() -> Opt(String) {
  opt.new("output-db-path")
  |> opt.help("The path and filename to save the database to")
}

fn db_path_opt() -> Opt(String) {
  opt.new("db-path")
  |> opt.help("The path and filename to the applicatoin database")
}
