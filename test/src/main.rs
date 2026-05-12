mod card;
mod deck;
mod player;
mod game;

use colored::Colorize;
use player::Player;
use game::Game;

fn main() {
    println!("{}", concat!(
        "\n  ╔═══════════════════════════════╗\n",
        "  ║     CARD BATTLER CLI v0.1     ║\n",
        "  ║   Hearthstone-style Dueling   ║\n",
        "  ╚═══════════════════════════════╝\n"
    ).cyan().bold());

    println!("Welcome! You'll face the AI in a card battle.");
    println!("First to reach 0 HP loses.\n");

    let player_deck = deck::make_balanced_deck();
    let enemy_deck = deck::make_balanced_deck();

    let player = Player::new("You", player_deck, false);
    let enemy = Player::new("Enemy", enemy_deck, true);

    let mut game = Game::new(player, enemy);
    game.run();

    println!("\nThanks for playing!");
}
