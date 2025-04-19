const std = @import("std");
const rl = @import("raylib");
const zb = @import("zbox2d");

/// Settings:
/// Tweak these values to play around with this example.
const settings = struct {
    const display = struct {
        const width = 960;
        const height = 640;
        const fps = 60;
        // Enable this, if your're using a monitor with high resolution such as 4K.
        const enable_highdpi = true;

        pub fn hw() f32 {
            return @as(f32, @floatFromInt(width)) / 2;
        }

        pub fn hh() f32 {
            return @as(f32, @floatFromInt(height)) / 2;
        }
    };
    const physics = struct {
        // PPM: Pixels per meter (100px = 1m)
        const ppm = 100;
        // NOTE: Real gravity would be too slow, so we're going for a higher value.
        // const gravity = 9.81;
        const gravity = 40;
        const time_step = 1.0 / 60.0;
        const sub_step_count = 6;
    };
};

pub fn main() !void {
    // Setup raylib.
    rl.setConfigFlags(.{ .window_highdpi = settings.display.enable_highdpi });
    rl.setTargetFPS(settings.display.fps);
    rl.initWindow(
        settings.display.width,
        settings.display.height,
        "zbox2d - 2d platformer example",
    );
    defer rl.closeWindow();

    // Setup box2d world.
    zb.b2SetLengthUnitsPerMeter(settings.physics.ppm);
    var worldDef = zb.b2DefaultWorldDef();
    worldDef.gravity.y = settings.physics.gravity * settings.physics.ppm;
    const world = zb.b2CreateWorld(&worldDef);
    defer zb.b2DestroyWorld(world);

    var state = State.init(std.heap.c_allocator);
    defer state.deinit();

    // Create player.
    try state.addPlayer(createPlayer(
        world,
        // Position the player at the top of the screen with 50px offset.
        .{ .x = settings.display.hw(), .y = 50 },
        rl.Vector2{ .x = 40, .y = 80 },
    ));

    // Create walls.
    try state.addEntity(createPlatform(
        world,
        .{ .x = 0, .y = settings.display.hh() },
        rl.Vector2{ .x = 1, .y = settings.display.height },
    ));
    try state.addEntity(createPlatform(
        world,
        .{ .x = settings.display.width, .y = settings.display.hh() },
        rl.Vector2{ .x = 1, .y = settings.display.height },
    ));

    // Create platforms.
    try state.addEntity(createPlatform(
        world,
        .{ .x = settings.display.hw(), .y = settings.display.height - 50 },
        rl.Vector2{ .x = 500, .y = 25 },
    ));
    try state.addEntity(createPlatform(
        world,
        .{ .x = settings.display.width - 250 / 2, .y = settings.display.height - 250 },
        rl.Vector2{ .x = 250, .y = 25 },
    ));

    // Create platform tiles.
    // This demonstrates how indvidual tiles cause so called *ghost collisions*.
    // (see https://box2d.org/documentation/md_collision.html#autotoc_md37)
    // According to the docs, this issue can be overcome with chain segments (`b2ChainSegment`).
    // I was too lazy to use chain segments for now, so ...
    for (0..10) |i| {
        try state.addEntity(createPlatform(
            world,
            .{
                .x = @as(f32, @floatFromInt(i)) * 25 + 25 / 2,
                .y = settings.display.height - 250,
            },
            rl.Vector2{ .x = 25, .y = 25 },
        ));
    }

    // Main loop.
    while (state.running) {
        handleInput(&state);
        handlePlayerInput(&state);

        // Reset box position if necessary.
        if (rl.isKeyPressed(rl.KeyboardKey.key_r)) {
            const body = zb.b2Shape_GetBody(state.player().shape);
            zb.b2Body_Disable(body);
            zb.b2Body_SetTransform(
                body,
                zb.b2Vec2{ .x = settings.display.hw(), .y = 150 },
                zb.b2Body_GetRotation(body),
            );
            zb.b2Body_Enable(body);
        }

        // Update physics.
        if (state.physics_enabled) {
            zb.b2World_Step(world, settings.physics.time_step, settings.physics.sub_step_count);
        }

        // Render scene.
        rl.beginDrawing();
        rl.clearBackground(rl.Color.dark_gray);

        for (state.entities.items) |*entity| {
            renderEntity(entity);
        }

        if (state.debug_enabled) {
            for (state.entities.items) |*entity| {
                debugRenderEntity(entity);
            }
            rl.drawFPS(10, 10);
        }

        const text_x = settings.display.width - 300;
        const font_size = 24;
        rl.drawText("[Q]  quit", text_x, font_size * 1, font_size, rl.Color.black);
        rl.drawText("[P]  toggle physics", text_x, font_size * 2, font_size, rl.Color.black);
        rl.drawText("[R]  reset", text_x, font_size * 3, font_size, rl.Color.black);
        rl.drawText("[F1] toggle debug mode", text_x, font_size * 4, font_size, rl.Color.black);
        if (state.physics_enabled) {
            rl.drawText("Physics enabled", text_x, font_size * 6, font_size, rl.Color.red);
        } else {
            rl.drawText("Physics disabled", text_x, font_size * 6, font_size, rl.Color.gray);
        }

        rl.endDrawing();
    }
}

const State = struct {
    /// Controls wether game is running or not.
    running: bool,
    /// Controls wether physics are enabled or not.
    physics_enabled: bool = true,
    /// Controls wether debug mode is enabled or not.
    debug_enabled: bool = false,

    // world: *zb.b2WorldId,
    player_entity_index: usize,

    entities: std.ArrayList(Entity),

    pub fn init(allocator: std.mem.Allocator) State {
        return State{
            .running = true,
            .player_entity_index = undefined,
            .entities = std.ArrayList(Entity).init(allocator),
        };
    }

    pub fn deinit(self: *State) void {
        self.entities.deinit();
    }

    pub fn addEntity(self: *State, entity: Entity) !void {
        try self.entities.append(entity);
    }

    pub fn addPlayer(self: *State, entity: Entity) !void {
        try self.addEntity(entity);
        self.player_entity_index = self.entities.items.len - 1;
    }

    pub fn player(self: *State) *Entity {
        return &self.entities.items[self.player_entity_index];
    }
};

const Entity = struct {
    const Self = @This();

    shape: zb.b2ShapeId,
    size: rl.Vector2,
    color: rl.Color,

    pub fn fromPhysicsShape(shape: zb.b2ShapeId, size: rl.Vector2, color: rl.Color) Self {
        return Self{
            .shape = shape,
            .size = size,
            .color = color,
        };
    }

    pub fn getBody(self: Self) zb.b2BodyId {
        return zb.b2Shape_GetBody(self.shape);
    }

    pub fn getPos(self: Self) rl.Vector2 {
        return toVector2(zb.b2Body_GetWorldPoint(
            self.getBody(),
            zb.b2Vec2{ .x = -self.size.x / 2, .y = -self.size.y / 2 },
        ));
    }

    pub fn getVelocity(self: Self) rl.Vector2 {
        return toVector2(zb.b2Body_GetLinearVelocity(self.getBody()));
    }

    pub fn setVelocity(self: Self, velocity: rl.Vector2) void {
        zb.b2Body_SetLinearVelocity(
            self.getBody(),
            .{
                .x = velocity.x,
                .y = velocity.y,
            },
        );
    }

    pub fn getAngle(self: Self) f32 {
        const rotation = zb.b2Body_GetRotation(self.getBody());
        return zb.b2Rot_GetAngle(rotation);
    }
};

/// Creates a dynamic physics body, that acts as a player.
fn createPlayer(world: zb.b2WorldId, position: rl.Vector2, size: rl.Vector2) Entity {
    var body_def = zb.b2DefaultBodyDef();
    body_def.type = zb.b2_dynamicBody;
    body_def.position = zb.b2Vec2{ .x = position.x, .y = position.y };
    body_def.fixedRotation = true;
    body_def.linearDamping = 0;
    const body = zb.b2CreateBody(world, &body_def);
    const polygon = zb.b2MakeBox(size.x / 2, size.y / 2);
    var shape_def = zb.b2DefaultShapeDef();
    shape_def.density = 1;
    shape_def.friction = 0;
    shape_def.restitution = 0;
    const shape = zb.b2CreatePolygonShape(body, &shape_def, &polygon);
    return Entity.fromPhysicsShape(shape, size, rl.Color.maroon);
}

/// Creates a static physics body, for the player to collide with.
fn createPlatform(world: zb.b2WorldId, position: rl.Vector2, size: rl.Vector2) Entity {
    var body_def = zb.b2DefaultBodyDef();
    body_def.position = zb.b2Vec2{ .x = position.x, .y = position.y };
    const body = zb.b2CreateBody(world, &body_def);
    // NOTE: In box2d we need to take half of width and height when creating the
    // polygon, because box2d calculates the sizes from the body's center point.
    const polygon = zb.b2MakeBox(size.x / 2, size.y / 2);
    var shape_def = zb.b2DefaultShapeDef();
    shape_def.density = 1;
    shape_def.restitution = 0;
    const shape = zb.b2CreatePolygonShape(body, &shape_def, &polygon);
    return Entity.fromPhysicsShape(shape, size, rl.Color.brown);
}

/// Handle keyboard input.
fn handleInput(state: *State) void {
    // Toggle physics.
    if (rl.isKeyPressed(rl.KeyboardKey.key_p)) {
        state.physics_enabled = !state.physics_enabled;
    }

    // Toggle debug mode.
    if (rl.isKeyPressed(rl.KeyboardKey.key_f1)) {
        state.debug_enabled = !state.debug_enabled;
    }

    // Close window when [ESC] or [Q] is pressed or if window is closed
    // manually.
    if (rl.isKeyPressed(rl.KeyboardKey.key_q) or rl.windowShouldClose()) {
        state.running = false;
    }
}

fn handlePlayerInput(state: *State) void {
    const max_velocity = 600;
    const speed = 50;
    const jump_speed = 1500;
    const deceleration_factor = 0.25;
    var vel = state.player().getVelocity();

    if (rl.isKeyDown(rl.KeyboardKey.key_left) or rl.isKeyDown(rl.KeyboardKey.key_h)) {
        vel.x -= speed;
    } else if (rl.isKeyDown(rl.KeyboardKey.key_right) or rl.isKeyDown(rl.KeyboardKey.key_l)) {
        vel.x += speed;
    } else {
        // If player is not actively moving, decelerate entity.
        // We could use box2d's `friction` property for this, but that would
        // only work if the entity is touching another physics body.
        vel.x += -vel.x * deceleration_factor;
        // Stop entity if velocity falls under threshold.
        if (@abs(vel.x) < 0.1) {
            vel.x = 0;
        }
    }

    if (rl.isKeyPressed(rl.KeyboardKey.key_space)) {
        vel.y = -jump_speed;
    }

    // Clamp X velocity.
    vel.x = std.math.clamp(vel.x, -max_velocity, max_velocity);
    state.player().setVelocity(vel);
}

/// Convert a box2d `b2Vec2` to a raylib `Vector2`.
fn toVector2(b2vec: zb.b2Vec2) rl.Vector2 {
    return rl.Vector2{ .x = b2vec.x, .y = b2vec.y };
}

/// Render given entity.
fn renderEntity(entity: *Entity) void {
    const pos = entity.getPos();
    const radians = entity.getAngle();

    rl.drawRectanglePro(
        .{
            .x = pos.x,
            .y = pos.y,
            .width = entity.size.x,
            .height = entity.size.y,
        },
        .{ .x = 0, .y = 0 },
        180.0 / std.math.pi * radians,
        entity.color,
    );
}

/// Render debug information for given entity.
fn debugRenderEntity(entity: *Entity) void {
    const body = entity.getBody();
    const hx = entity.size.x / 2;
    const hy = entity.size.y / 2;

    // Draw upper-left point.
    const point_ut = zb.b2Body_GetWorldPoint(body, zb.b2Vec2{ .x = -hx, .y = -hy });
    rl.drawCircleV(toVector2(point_ut), 5.0, rl.Color.black);
    // Draw center point.
    const point_center = zb.b2Body_GetWorldPoint(body, zb.b2Vec2{ .x = 0.0, .y = 0.0 });
    rl.drawCircleV(toVector2(point_center), 5.0, rl.Color.blue);
    // Draw lower-right point.
    const point_lr = zb.b2Body_GetWorldPoint(body, zb.b2Vec2{ .x = hx, .y = hy });
    rl.drawCircleV(toVector2(point_lr), 5.0, rl.Color.red);
}
