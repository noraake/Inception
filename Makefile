DATA_PATH = /home/noakebli/data


all:
	@mkdir -p $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress
	@docker compose -f srcs/docker-compose.yml --env-file srcs/.env up --build

down:
	@docker compose -f srcs/docker-compose.yml --env-file srcs/.env down

clean:
	@docker compose -f srcs/docker-compose.yml --env-file srcs/.env down -v

fclean: clean
	@docker system prune -f
	@sudo rm -rf $(DATA_PATH)

re: fclean all
