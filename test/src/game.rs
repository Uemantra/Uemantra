use crate::card::{Card, CardEffect, BattlecryEffect, DeathrattleEffect, CardType, SpellEffect};
use crate::player::Player;
use colored::Colorize;
use std::io::{self, Write};

pub struct Game {
    pub player: Player,
    pub enemy: Player,
    pub turn: u32,
    pub log: Vec<String>,
}

impl Game {
    pub fn new(player: Player, enemy: Player) -> Self {
        Game { player, enemy, turn: 1, log: vec![] }
    }

    pub fn start(&mut self) {
        self.player.draw(3);
        self.enemy.draw(4);
    }

    fn log(&mut self, msg: String) {
        self.log.push(msg.clone());
    }

    pub fn run(&mut self) {
        self.start();
        loop {
            self.player_turn();
            if self.check_end() { break; }
            self.enemy_turn();
            if self.check_end() { break; }
            self.turn += 1;
        }
    }

    fn is_over(&self) -> bool {
        self.player.is_dead() || self.enemy.is_dead()
    }

    fn check_end(&mut self) -> bool {
        if self.player.is_dead() {
            println!("\n{}", "=== YOU LOST! ===".red().bold());
            return true;
        }
        if self.enemy.is_dead() {
            println!("\n{}", "=== YOU WIN! ===".green().bold());
            return true;
        }
        false
    }

    // ─── DISPLAY ─────────────────────────────────────────────────────────────

    fn display_state(&self) {
        println!("\n{}", "═".repeat(60).dimmed());
        println!("{}", format!("Turn {}", self.turn).bold());
        println!("{}", "─".repeat(60).dimmed());

        // Enemy status
        println!("{}", self.enemy.display_status());
        println!("Enemy board:");
        println!("{}", self.enemy.display_board_minions(false));

        println!("{}", "─".repeat(60).dimmed());

        // Player status
        println!("{}", self.player.display_status());
        println!("Your board:");
        println!("{}", self.player.display_board_minions(true));

        println!("{}", "─".repeat(60).dimmed());
        println!("Your hand:");
        for (i, card) in self.player.hand.iter().enumerate() {
            println!("  {}", card.display_hand(i));
        }
        println!("{}", "═".repeat(60).dimmed());
    }

    fn display_recent_log(&self, n: usize) {
        let start = self.log.len().saturating_sub(n);
        for msg in &self.log[start..] {
            println!("  {}", msg.dimmed());
        }
    }

    // ─── PLAYER TURN ─────────────────────────────────────────────────────────

    fn player_turn(&mut self) {
        self.player.start_turn();
        let msgs = self.player.draw(1);
        for m in msgs { self.log(m); }

        loop {
            self.display_state();
            if !self.log.is_empty() {
                println!("Recent:");
                self.display_recent_log(4);
            }
            println!("\n{}", "Commands:".bold());
            println!("  play <n>        — play card n from hand");
            println!("  attack <m> <t>  — minion m attacks enemy minion t (or 'hero')");
            println!("  end             — end your turn");

            let input = Self::read_input();
            let parts: Vec<&str> = input.trim().split_whitespace().collect();

            match parts.as_slice() {
                ["end"] => break,
                ["play", n] => {
                    if let Ok(idx) = n.parse::<usize>() {
                        let msg = self.play_player_card(idx);
                        self.log(msg);
                    } else {
                        println!("{}", "Invalid index.".red());
                    }
                }
                ["attack", m, t] => {
                    if let Ok(mi) = m.parse::<usize>() {
                        let msg = self.player_attack(mi, t);
                        self.log(msg);
                        self.remove_dead();
                    } else {
                        println!("{}", "Invalid index.".red());
                    }
                }
                _ => println!("{}", "Unknown command.".red()),
            }

            if self.is_over() { return; }
        }
    }

    fn play_player_card(&mut self, idx: usize) -> String {
        if idx >= self.player.hand.len() {
            return "No card at that index.".to_string();
        }
        let cost = self.player.hand[idx].cost;
        if cost > self.player.mana {
            return format!("Not enough mana ({} needed, {} available).", cost, self.player.mana);
        }
        if self.player.board.len() >= 7 && matches!(self.player.hand[idx].card_type, CardType::Minion) {
            return "Board is full!".to_string();
        }

        let mut card = self.player.hand.remove(idx);
        self.player.mana -= cost;

        let name = card.name.clone();
        let msg = format!("You played {}.", name);

        match card.card_type.clone() {
            CardType::Minion => {
                let effects = card.effects.clone();
                card.just_played = true;
                self.player.board.push(card);
                for effect in &effects {
                    if let CardEffect::Battlecry(bc) = effect {
                        self.apply_player_battlecry(bc.clone());
                    }
                }
            }
            CardType::Spell(effect) => {
                self.apply_player_spell(&effect);
            }
        }
        msg
    }

    fn apply_player_battlecry(&mut self, bc: BattlecryEffect) {
        match bc {
            BattlecryEffect::DealDamage(n) => {
                self.enemy.take_damage(n as i32);
                self.log(format!("Battlecry: dealt {} damage to enemy hero.", n));
            }
            BattlecryEffect::HealHero(n) => {
                self.player.heal(n as i32);
                self.log(format!("Battlecry: healed {} HP.", n));
            }
            BattlecryEffect::DrawCard => {
                let msgs = self.player.draw(1);
                for m in msgs { self.log(m); }
            }
            BattlecryEffect::GainArmor(n) => {
                self.player.armor += n as i32;
                self.log(format!("Battlecry: gained {} armor.", n));
            }
            BattlecryEffect::BuffMinion(a, h) => {
                if self.player.board.is_empty() {
                    return;
                }
                self.display_state();
                println!("Choose a friendly minion to buff (0-{}):", self.player.board.len() - 1);
                let input = Self::read_input();
                if let Ok(i) = input.trim().parse::<usize>() {
                    if i < self.player.board.len() {
                        self.player.board[i].attack += a;
                        self.player.board[i].health += h;
                        self.player.board[i].max_health += h;
                        let name = self.player.board[i].name.clone();
                        self.log(format!("Battlecry: buffed {} with +{}/+{}.", name, a, h));
                    }
                }
            }
        }
    }

    fn apply_player_spell(&mut self, effect: &SpellEffect) {
        match effect {
            SpellEffect::DealDamage(n) => {
                self.enemy.take_damage(*n as i32);
                self.log(format!("Spell: dealt {} damage to enemy hero.", n));
            }
            SpellEffect::DealDamageAll(n) => {
                for m in &mut self.enemy.board {
                    m.take_damage(*n as i32);
                }
                self.enemy.take_damage(*n as i32);
                self.log(format!("Spell: dealt {} damage to all enemies.", n));
                self.remove_dead();
            }
            SpellEffect::HealHero(n) => {
                self.player.heal(*n as i32);
                self.log(format!("Spell: healed {} HP.", n));
            }
            SpellEffect::DrawCards(n) => {
                let msgs = self.player.draw(*n);
                for m in msgs { self.log(m); }
            }
            SpellEffect::GainArmor(n) => {
                self.player.armor += *n as i32;
                self.log(format!("Spell: gained {} armor.", n));
            }
            SpellEffect::BuffMinion(a, h) => {
                if self.player.board.is_empty() {
                    self.log("No friendly minions to buff.".to_string());
                    return;
                }
                println!("Choose a friendly minion to buff (0-{}):", self.player.board.len() - 1);
                let input = Self::read_input();
                if let Ok(i) = input.trim().parse::<usize>() {
                    if i < self.player.board.len() {
                        self.player.board[i].attack += a;
                        self.player.board[i].health += h;
                        self.player.board[i].max_health += h;
                        let name = self.player.board[i].name.clone();
                        self.log(format!("Spell: buffed {} with +{}/+{}.", name, a, h));
                    }
                }
            }
            SpellEffect::Silence => {
                println!("Choose enemy minion to silence (0-{}):", self.enemy.board.len().saturating_sub(1));
                let input = Self::read_input();
                if let Ok(i) = input.trim().parse::<usize>() {
                    if i < self.enemy.board.len() {
                        self.enemy.board[i].effects.clear();
                        self.enemy.board[i].divine_shield_active = false;
                        self.enemy.board[i].is_frozen = false;
                        let name = self.enemy.board[i].name.clone();
                        self.log(format!("Spell: silenced {}.", name));
                    }
                }
            }
        }
    }

    fn player_attack(&mut self, mi: usize, target: &str) -> String {
        if mi >= self.player.board.len() {
            return "No minion at that index.".to_string();
        }
        if !self.player.can_attack_with(mi) {
            return "That minion can't attack right now.".to_string();
        }
        let enemy_has_taunt = self.enemy.has_minion_with_taunt();

        if target == "hero" {
            if enemy_has_taunt {
                return "You must attack a taunt minion first.".to_string();
            }
            let atk = self.player.board[mi].attack;
            self.player.board[mi].has_attacked = true;
            self.enemy.take_damage(atk);
            return format!("{} attacked enemy hero for {} damage.", self.player.board[mi].name, atk);
        }

        if let Ok(ti) = target.parse::<usize>() {
            if ti >= self.enemy.board.len() {
                return "No enemy minion at that index.".to_string();
            }
            if enemy_has_taunt && !self.enemy.board[ti].has_taunt() {
                return "You must attack a taunt minion first.".to_string();
            }

            let atk = self.player.board[mi].attack;
            let enemy_atk = self.enemy.board[ti].attack;
            let attacker_name = self.player.board[mi].name.clone();
            let target_name = self.enemy.board[ti].name.clone();

            self.player.board[mi].has_attacked = true;
            let dmg_dealt = self.enemy.board[ti].take_damage(atk);
            let dmg_taken = self.player.board[mi].take_damage(enemy_atk);

            format!(
                "{} attacked {} ({} dmg dealt, {} dmg taken).",
                attacker_name, target_name, dmg_dealt, dmg_taken
            )
        } else {
            "Invalid target. Use a number or 'hero'.".to_string()
        }
    }

    // ─── ENEMY TURN ──────────────────────────────────────────────────────────

    fn enemy_turn(&mut self) {
        println!("\n{}", "--- Enemy Turn ---".yellow().bold());
        self.enemy.start_turn();
        let msgs = self.enemy.draw(1);
        for m in msgs { self.log(m); }

        // AI: play all affordable cards greedily (minions first by cost, then spells)
        let mut played = true;
        while played {
            played = false;
            let playable: Vec<usize> = self.enemy.hand.iter().enumerate()
                .filter(|(_, c)| c.cost <= self.enemy.mana && (self.enemy.board.len() < 7 || !matches!(c.card_type, CardType::Minion)))
                .map(|(i, _)| i)
                .collect();

            if let Some(&idx) = playable.first() {
                let msg = self.play_enemy_card(idx);
                self.log(msg.clone());
                println!("  Enemy: {}", msg);
                self.remove_dead();
                played = true;
            }
        }

        // AI: attack with all minions
        let minion_count = self.enemy.board.len();
        for mi in 0..minion_count {
            if !self.enemy.can_attack_with(mi) { continue; }
            let msg = self.enemy_attack(mi);
            self.log(msg.clone());
            println!("  Enemy: {}", msg);
            self.remove_dead();
            if self.is_over() { return; }
        }
    }

    fn play_enemy_card(&mut self, idx: usize) -> String {
        let cost = self.enemy.hand[idx].cost;
        if cost > self.enemy.mana { return String::new(); }

        let mut card = self.enemy.hand.remove(idx);
        self.enemy.mana -= cost;
        let name = card.name.clone();

        match card.card_type.clone() {
            CardType::Minion => {
                let effects = card.effects.clone();
                card.just_played = true;
                self.enemy.board.push(card);
                for effect in &effects {
                    if let CardEffect::Battlecry(bc) = effect {
                        self.apply_enemy_battlecry(bc.clone());
                    }
                }
            }
            CardType::Spell(effect) => {
                self.apply_enemy_spell(&effect);
            }
        }
        format!("Enemy played {}.", name)
    }

    fn apply_enemy_battlecry(&mut self, bc: BattlecryEffect) {
        match bc {
            BattlecryEffect::DealDamage(n) => {
                self.player.take_damage(n as i32);
                self.log(format!("Enemy battlecry: dealt {} damage to you.", n));
            }
            BattlecryEffect::HealHero(n) => {
                self.enemy.heal(n as i32);
            }
            BattlecryEffect::DrawCard => {
                let msgs = self.enemy.draw(1);
                for m in msgs { self.log(m); }
            }
            BattlecryEffect::GainArmor(n) => {
                self.enemy.armor += n as i32;
            }
            BattlecryEffect::BuffMinion(a, h) => {
                if let Some(m) = self.enemy.board.last_mut() {
                    m.attack += a;
                    m.health += h;
                    m.max_health += h;
                }
            }
        }
    }

    fn apply_enemy_spell(&mut self, effect: &SpellEffect) {
        match effect {
            SpellEffect::DealDamage(n) => { self.player.take_damage(*n as i32); }
            SpellEffect::DealDamageAll(n) => {
                for m in &mut self.player.board { m.take_damage(*n as i32); }
                self.player.take_damage(*n as i32);
                self.remove_dead();
            }
            SpellEffect::HealHero(n) => { self.enemy.heal(*n as i32); }
            SpellEffect::DrawCards(n) => {
                let msgs = self.enemy.draw(*n);
                for m in msgs { self.log(m); }
            }
            SpellEffect::GainArmor(n) => { self.enemy.armor += *n as i32; }
            SpellEffect::BuffMinion(a, h) => {
                if let Some(m) = self.enemy.board.last_mut() {
                    m.attack += a; m.health += h; m.max_health += h;
                }
            }
            SpellEffect::Silence => {
                if let Some(m) = self.player.board.last_mut() {
                    m.effects.clear();
                    m.divine_shield_active = false;
                }
            }
        }
    }

    fn enemy_attack(&mut self, mi: usize) -> String {
        let atk = self.enemy.board[mi].attack;
        let attacker_name = self.enemy.board[mi].name.clone();

        let player_has_taunt = self.player.has_minion_with_taunt();

        if player_has_taunt {
            // attack a taunt minion
            if let Some(ti) = self.player.board.iter().position(|m| m.has_taunt()) {
                let target_name = self.player.board[ti].name.clone();
                let enemy_atk = self.player.board[ti].attack;
                self.enemy.board[mi].has_attacked = true;
                let dmg_dealt = self.player.board[ti].take_damage(atk);
                let dmg_taken = self.enemy.board[mi].take_damage(enemy_atk);
                return format!(
                    "Enemy {} attacked your {} ({} dmg dealt, {} dmg taken).",
                    attacker_name, target_name, dmg_dealt, dmg_taken
                );
            }
        }

        // Attack player hero directly if no taunt or no minions
        if self.player.board.is_empty() || !player_has_taunt {
            let target = if self.player.board.is_empty() {
                "hero".to_string()
            } else {
                // 50% chance to attack a minion
                if rand::random::<bool>() && !self.player.board.is_empty() {
                    let ti = rand::random::<usize>() % self.player.board.len();
                    let target_name = self.player.board[ti].name.clone();
                    let enemy_atk = self.player.board[ti].attack;
                    self.enemy.board[mi].has_attacked = true;
                    let dmg_dealt = self.player.board[ti].take_damage(atk);
                    let dmg_taken = self.enemy.board[mi].take_damage(enemy_atk);
                    return format!(
                        "Enemy {} attacked your {} ({} dmg dealt, {} dmg taken).",
                        attacker_name, target_name, dmg_dealt, dmg_taken
                    );
                } else {
                    "hero".to_string()
                }
            };

            if target == "hero" {
                self.enemy.board[mi].has_attacked = true;
                self.player.take_damage(atk);
                return format!("Enemy {} attacked your hero for {} damage.", attacker_name, atk);
            }
        }
        String::new()
    }

    // ─── CLEANUP ─────────────────────────────────────────────────────────────

    fn remove_dead(&mut self) {
        let dead_enemy: Vec<Card> = {
            let mut dead = vec![];
            let mut i = 0;
            while i < self.enemy.board.len() {
                if !self.enemy.board[i].is_alive() { dead.push(self.enemy.board.remove(i)); }
                else { i += 1; }
            }
            dead
        };
        let dead_player: Vec<Card> = {
            let mut dead = vec![];
            let mut i = 0;
            while i < self.player.board.len() {
                if !self.player.board[i].is_alive() { dead.push(self.player.board.remove(i)); }
                else { i += 1; }
            }
            dead
        };

        for card in dead_enemy {
            self.log(format!("Enemy {} died.", card.name));
            self.handle_deathrattle(&card, false);
        }
        for card in dead_player {
            self.log(format!("Your {} died.", card.name));
            self.handle_deathrattle(&card, true);
        }
    }

    fn handle_deathrattle(&mut self, card: &Card, is_player: bool) {
        for effect in &card.effects {
            if let CardEffect::Deathrattle(dr) = effect {
                match dr {
                    DeathrattleEffect::DrawCard => {
                        if is_player {
                            let msgs = self.player.draw(1);
                            for m in msgs { self.log(m); }
                        } else {
                            let msgs = self.enemy.draw(1);
                            for m in msgs { self.log(m); }
                        }
                    }
                    DeathrattleEffect::DealDamage(n) => {
                        if is_player {
                            self.enemy.take_damage(*n as i32);
                        } else {
                            self.player.take_damage(*n as i32);
                        }
                        self.log(format!("Deathrattle: dealt {} damage.", n));
                    }
                    DeathrattleEffect::SummonToken => {
                        let mut token = Card::new_minion(0, "Damaged Golem", 1, 2, 1, vec![]);
                        token.just_played = false;
                        if is_player && self.player.board.len() < 7 {
                            self.player.board.push(token);
                            self.log("Deathrattle: summoned a Damaged Golem (2/1).".to_string());
                        } else if !is_player && self.enemy.board.len() < 7 {
                            self.enemy.board.push(token);
                            self.log("Deathrattle: enemy summoned a Damaged Golem (2/1).".to_string());
                        }
                    }
                }
            }
        }
    }

    fn read_input() -> String {
        print!("> ");
        io::stdout().flush().unwrap();
        let mut buf = String::new();
        match io::stdin().read_line(&mut buf) {
            Ok(0) | Err(_) => "end".to_string(),
            Ok(_) => buf.trim().trim_start_matches('\u{feff}').trim().to_string(),
        }
    }
}
